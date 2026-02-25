/**
 * Git worktree isolation for subagent tasks.
 *
 * Each subagent runs in a throwaway worktree created from HEAD,
 * with the parent's dirty state (staged, unstaged, untracked) applied.
 * After completion, a delta patch is extracted containing only
 * the subagent's changes relative to that baseline.
 */

import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

let nextId = 0;
function uniqueId(): string {
	return `${Date.now()}-${process.pid}-${nextId++}`;
}

export interface WorktreeBaseline {
	repoRoot: string;
	staged: string;
	unstaged: string;
	untracked: string[];
}

function execGit(args: string[], cwd: string, env?: Record<string, string>): Promise<{ code: number; stdout: string; stderr: string }> {
	return new Promise((resolve) => {
		const proc = spawn("git", args, {
			cwd,
			env: { ...process.env, ...env },
			stdio: ["ignore", "pipe", "pipe"],
		});
		let stdout = "";
		let stderr = "";
		proc.stdout.on("data", (d) => (stdout += d.toString()));
		proc.stderr.on("data", (d) => (stderr += d.toString()));
		proc.on("close", (code) => resolve({ code: code ?? 1, stdout, stderr }));
		proc.on("error", (err) => resolve({ code: 1, stdout: "", stderr: err.message }));
	});
}

export async function getRepoRoot(cwd: string): Promise<string> {
	const result = await execGit(["rev-parse", "--show-toplevel"], cwd);
	if (result.code !== 0) {
		throw new Error(`Not a git repository: ${result.stderr.trim()}`);
	}
	return result.stdout.trim();
}

export async function captureBaseline(repoRoot: string): Promise<WorktreeBaseline> {
	const [staged, unstaged, untrackedRaw] = await Promise.all([
		execGit(["diff", "--cached", "--binary"], repoRoot),
		execGit(["diff", "--binary"], repoRoot),
		execGit(["ls-files", "--others", "--exclude-standard"], repoRoot),
	]);

	const untracked = untrackedRaw.stdout
		.split("\n")
		.map((l) => l.trim())
		.filter((l) => l.length > 0);

	return {
		repoRoot,
		staged: staged.stdout,
		unstaged: unstaged.stdout,
		untracked,
	};
}

function getWorktreeDir(repoRoot: string, id: string): string {
	const encoded = repoRoot.replace(/^[/\\]/, "").replace(/[/\\:]/g, "-");
	return path.join(os.tmpdir(), "pi-worktrees", encoded, id);
}

async function writeTempPatch(patch: string): Promise<string> {
	const p = path.join(os.tmpdir(), `pi-wt-patch-${uniqueId()}.patch`);
	fs.writeFileSync(p, patch, "utf-8");
	return p;
}

async function applyPatch(
	cwd: string,
	patch: string,
	options?: { cached?: boolean; env?: Record<string, string> },
): Promise<void> {
	if (!patch.trim()) return;
	const tempPath = await writeTempPatch(patch);
	try {
		const args = ["apply", "--binary", tempPath];
		if (options?.cached) args.splice(1, 0, "--cached");
		await execGit(args, cwd, options?.env);
	} finally {
		try { fs.unlinkSync(tempPath); } catch { /* ignore */ }
	}
}

export async function ensureWorktree(repoRoot: string, id: string): Promise<string> {
	const worktreeDir = getWorktreeDir(repoRoot, id);
	fs.mkdirSync(path.dirname(worktreeDir), { recursive: true });

	// Clean up stale worktree at this path (crash recovery)
	await execGit(["worktree", "remove", "-f", worktreeDir], repoRoot);
	try { fs.rmSync(worktreeDir, { recursive: true, force: true }); } catch { /* ignore */ }

	const result = await execGit(["worktree", "add", "--detach", worktreeDir, "HEAD"], repoRoot);
	if (result.code !== 0) {
		throw new Error(`Failed to create worktree: ${result.stderr.trim()}`);
	}
	return worktreeDir;
}

export async function applyBaseline(worktreeDir: string, baseline: WorktreeBaseline): Promise<void> {
	// Apply staged changes to both index and working tree
	await applyPatch(worktreeDir, baseline.staged, { cached: true });
	await applyPatch(worktreeDir, baseline.staged);
	// Apply unstaged changes to working tree
	await applyPatch(worktreeDir, baseline.unstaged);

	// Copy untracked files
	for (const entry of baseline.untracked) {
		const source = path.join(baseline.repoRoot, entry);
		const destination = path.join(worktreeDir, entry);
		try {
			fs.mkdirSync(path.dirname(destination), { recursive: true });
			fs.cpSync(source, destination, { recursive: true });
		} catch {
			// Source may have been deleted between capture and apply
		}
	}
}

export async function captureDeltaPatch(worktreeDir: string, baseline: WorktreeBaseline): Promise<string> {
	const tempIndex = path.join(os.tmpdir(), `pi-wt-index-${uniqueId()}`);
	try {
		// Build a temp index that represents the baseline state
		await execGit(["read-tree", "HEAD"], worktreeDir, { GIT_INDEX_FILE: tempIndex });
		if (baseline.staged.trim()) {
			const p = await writeTempPatch(baseline.staged);
			try {
				await execGit(["apply", "--cached", "--binary", p], worktreeDir, { GIT_INDEX_FILE: tempIndex });
			} finally {
				try { fs.unlinkSync(p); } catch { /* ignore */ }
			}
		}
		if (baseline.unstaged.trim()) {
			const p = await writeTempPatch(baseline.unstaged);
			try {
				await execGit(["apply", "--cached", "--binary", p], worktreeDir, { GIT_INDEX_FILE: tempIndex });
			} finally {
				try { fs.unlinkSync(p); } catch { /* ignore */ }
			}
		}

		// Diff the worktree against the baseline index = only subagent's changes
		const diff = await execGit(["diff", "--binary"], worktreeDir, { GIT_INDEX_FILE: tempIndex });

		// Capture newly created untracked files
		const currentUntrackedResult = await execGit(["ls-files", "--others", "--exclude-standard"], worktreeDir);
		const currentUntracked = currentUntrackedResult.stdout
			.split("\n")
			.map((l) => l.trim())
			.filter((l) => l.length > 0);
		const baselineUntracked = new Set(baseline.untracked);
		const newUntracked = currentUntracked.filter((e) => !baselineUntracked.has(e));

		if (newUntracked.length === 0) return diff.stdout;

		const untrackedDiffs = await Promise.all(
			newUntracked.map((entry) =>
				execGit(["diff", "--binary", "--no-index", "/dev/null", entry], worktreeDir).then((r) => r.stdout),
			),
		);

		const base = diff.stdout;
		return `${base}${base && !base.endsWith("\n") ? "\n" : ""}${untrackedDiffs.join("\n")}`;
	} finally {
		try { fs.unlinkSync(tempIndex); } catch { /* ignore */ }
	}
}

export async function cleanupWorktree(dir: string, repoRoot: string): Promise<void> {
	try {
		await execGit(["worktree", "remove", "-f", dir], repoRoot);
	} finally {
		try { fs.rmSync(dir, { recursive: true, force: true }); } catch { /* ignore */ }
	}
}

export async function applyPatchToRepo(repoRoot: string, patch: string): Promise<{ applied: boolean; error?: string }> {
	if (!patch.trim()) return { applied: true };
	const tempPath = await writeTempPatch(patch);
	try {
		const check = await execGit(["apply", "--check", "--binary", tempPath], repoRoot);
		if (check.code !== 0) {
			return { applied: false, error: check.stderr.trim() };
		}
		const apply = await execGit(["apply", "--binary", tempPath], repoRoot);
		if (apply.code !== 0) {
			return { applied: false, error: apply.stderr.trim() };
		}
		return { applied: true };
	} finally {
		try { fs.unlinkSync(tempPath); } catch { /* ignore */ }
	}
}
