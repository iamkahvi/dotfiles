# Worktree-Isolated Subagent Extension

A pi-mono extension that runs subagents in isolated git worktrees. Each subagent
gets a throwaway copy of the repo (at HEAD + your uncommitted changes), works
freely, and produces a delta patch. Patches are auto-applied when clean, or
surfaced for manual review when they conflict.

## Design

The parent agent controls each subagent's role entirely. No predefined agent
files are required. The parent specifies what the subagent should do via the
task description, and can optionally override the model, tools, and system
prompt per-task.

Named agent presets (markdown files in `~/.pi/agent/agents/`) are supported
but optional. They're useful as reusable shortcuts — e.g., a "scout" preset
that always uses haiku with read-only tools. When no agent name is given, a
bare default agent is used and the parent has full control.

## Why worktree isolation

The vanilla subagent extension runs all subagents in the real working directory.
This is fine for read-only tasks, but parallel agents that *write* to overlapping
files will clobber each other.

Worktree isolation solves this:
- Each subagent gets its own filesystem via `git worktree add --detach`
- The parent's dirty state (staged, unstaged, untracked) is replicated
- After completion, only the subagent's delta is extracted as a patch
- Patches are combined and applied atomically

## How it works

```
1. captureBaseline()     - snapshot staged/unstaged/untracked in real repo
2. ensureWorktree()      - git worktree add --detach /tmp/.../wt/<id> HEAD
3. applyBaseline()       - replay dirty state into worktree
4. pi --mode json -p ... - run subagent inside the worktree
5. captureDeltaPatch()   - diff worktree against baseline = only subagent's changes
6. applyPatchToRepo()    - git apply --check && git apply on real repo
7. cleanupWorktree()     - git worktree remove -f && rm -rf
```

## Installation

```bash
# Symlink the extension
mkdir -p ~/.pi/agent/extensions/worktree-subagent
ln -sf "$(pwd)/pi-worktree-subagent/index.ts" ~/.pi/agent/extensions/worktree-subagent/index.ts
ln -sf "$(pwd)/pi-worktree-subagent/agents.ts" ~/.pi/agent/extensions/worktree-subagent/agents.ts
ln -sf "$(pwd)/pi-worktree-subagent/worktree.ts" ~/.pi/agent/extensions/worktree-subagent/worktree.ts
```

Or test directly:

```bash
pi -e ./pi-worktree-subagent/index.ts
```

Optionally install agent presets:

```bash
mkdir -p ~/.pi/agent/agents
for f in pi-worktree-subagent/agents/*.md; do
  cp "$f" ~/.pi/agent/agents/
done
```

## Usage

### Parent controls everything (no agent file needed)

```
Run a subagent:
  task: "Add input validation to src/api/users.ts. Only modify that file."
  tools: "read,write,edit,bash"
  model: "claude-haiku-4-5"
  systemPrompt: "You are a focused implementer. Make minimal changes."
```

### Parallel with isolation (the main use case)

```
Run these in parallel with isolated: true:
  tasks:
    - task: "Add input validation to src/api/users.ts"
      tools: "read,write,edit"
    - task: "Add input validation to src/api/posts.ts"
      tools: "read,write,edit"
    - task: "Add rate limiting middleware to src/middleware/"
      tools: "read,write,edit,bash"
```

Each task runs in its own worktree. Patches are combined and applied atomically.

### Using a named preset

```
Use the scout agent to find all authentication code
```

This uses `~/.pi/agent/agents/scout.md` which predefines model (haiku),
tools (read-only), and system prompt. You can still override any field:

```
Use scout with model: claude-sonnet-4-5 to find auth code
```

### Chain with per-step configuration

```
Chain with isolated: true:
  1. task: "Find all API endpoints"
     model: "claude-haiku-4-5"
     tools: "read,grep,find,ls"
  2. task: "Add validation to all endpoints from {previous}"
     model: "claude-sonnet-4-5"
     tools: "read,write,edit,bash"
     systemPrompt: "Apply changes incrementally. Test after each file."
```

Step 1 runs cheap/fast on haiku with read-only tools. Step 2 gets the
full model with write access. Each step's patch is applied before the
next step runs.

## Schema

### Top-level parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `task` | string | Task description (single mode) |
| `agent` | string? | Named agent preset (optional, defaults to bare agent) |
| `model` | string? | Model override |
| `tools` | string? | Comma-separated tool list override |
| `systemPrompt` | string? | Additional system prompt |
| `tasks` | array? | Parallel task items |
| `chain` | array? | Sequential task items with `{previous}` |
| `isolated` | boolean? | Run in git worktrees (default: false) |
| `agentScope` | string? | "user", "project", or "both" |

### Task/chain item fields

| Field | Type | Description |
|-------|------|-------------|
| `task` | string | Task description (required) |
| `agent` | string? | Named agent preset |
| `model` | string? | Model override for this task |
| `tools` | string? | Tool list override for this task |
| `systemPrompt` | string? | Additional system prompt for this task |

## Patch behavior

| Scenario | Result |
|----------|--------|
| Single task, clean apply | Patch applied, changes in working tree |
| Parallel, all patches clean | Combined patch applied atomically |
| Parallel, patches conflict | No changes applied, patch files preserved |
| Chain, step N conflicts | Chain stops, earlier patches may be applied |
| No file changes | No patch generated |

When patches conflict, the tool result includes paths to `.patch` files
in `/tmp/pi-subagent-patches/`. The parent agent can read these and
apply changes manually.

## Files

| File | Purpose |
|------|---------|
| `index.ts` | Extension entry point, tool registration, rendering |
| `worktree.ts` | Git worktree lifecycle (create, baseline, delta, cleanup, apply) |
| `agents.ts` | Agent discovery from `~/.pi/agent/agents/` and `.pi/agents/` |
| `agents/*.md` | Optional agent presets (scout, planner, reviewer, worker) |
| `prompts/*.md` | Optional workflow prompt templates |

## Limitations

- Requires git. Non-git directories error when `isolated: true`.
- Submodules are not replicated into worktrees.
- Parallel patch conflicts are all-or-nothing.
- Binary untracked files are copied but may not round-trip through patches.
