# herdr-orchestrator

A declarative manager for herdr workspaces. It opens tabs in the correct
workspace, creates workspaces when needed, and reorganizes an existing
herdr server to match a desired layout — with a granular, per-action
permission model controlling everything it is allowed to touch.

Status: **design doc**. Nothing implemented yet.

## 1. Goals and non-goals

- Open tabs in the right workspace; create workspaces on demand.
- Reconcile a drifted live server toward the spec: plan → permission
  check → apply → verify. `plan` (dry run) always exists.
- Granular permissions: every mutation class gated independently,
  scoped by workspace/tab/pane, verdicts `allow` / `deny` / `ask`.
- Non-destructive default: nothing is closed or renamed without a rule
  or a confirmation.

Not a TUI or herdr replacement (it drives herdr through its API and
owns no terminal state), and not a process supervisor (it arranges
panes; it never keeps agents alive).

## 2. Herdr capabilities used (verified, v0.8.2 / protocol 20)

Full command reference lives in `herdr --help` and `herdr api schema
--json`. What the orchestrator relies on:

- `api snapshot` — live state: workspaces, tabs, panes, agents, focus.
  Source of truth, re-read at every plan/apply.
- `workspace|tab create/rename/focus/close` — with `--cwd --label --env`.
- `pane move <ID>` in three modes: into an existing tab
  (`--tab T --split right|down --target-pane P --ratio F`), a new tab
  (`--new-tab --workspace W --label T`), or a new workspace
  (`--new-workspace --label T --tab-label T`).
- `agent prompt/send-keys/read/wait` — for the (dangerous) agent hooks.

### Observed behaviors that constrain the design

Learned while moving a tab between workspaces:

1. **No atomic tab move.** `tab` has no `move`. Relocating a tab = one
   `pane move --new-tab` + N-1 `pane move --tab` to rebuild the layout.
2. **IDs are ephemeral.** `w9:t1`-style IDs don't survive a restart.
   They cannot be identity (§4).
3. **Numeric labels auto-renumber.** Removing a tab shifts the remaining
   numeric labels down. Labels are display hints, not keys.
4. **Duplicate labels are legal.** Matching can't assume uniqueness.
5. **Focus follows the moved pane.** Moving the focused pane refocuses
   the target workspace; the executor must snapshot and restore focus.
6. **Empty tabs self-close** when their last pane leaves.
7. **Move grammar is mode-dependent** (`--tab-label` only with
   `--new-workspace`). The command builder needs per-mode validation.

## 3. Desired state (`layout.toml`)

Workspaces and tabs have stable **logical names** (orchestrator-owned);
herdr labels are rendered output.

```toml
version = 1

[defaults]
shell = "fish"

[workspace.dotfiles]
label = "dotfiles"
cwd   = "~/dotfiles"

[workspace.dotfiles.tab.main]
cwd   = "~/dotfiles"
panes = [{ split = "right", ratio = 0.5, cmd = "pi" }]

[workspace.ledger]
label = "ledger"
cwd   = "~/ledger"

[workspace.ledger.tab.shell]
cwd = "~/ledger"

[workspace.ledger.tab.remote]
panes = [{ cmd = "pi" }]
match.agent_session_contains = "ledger"   # identity hint, see §4
```

- `panes` describes the split tree: first entry is the base pane, each
  subsequent entry splits from the previous.
- `cmd` starts an agent only in freshly created panes — never restarted
  on existing ones.
- `match.*` hints feed the identity resolver; all hints must match.
- Tab order follows declaration order, enforced best-effort.

## 4. Identity resolution (the hard part)

Spec entries are stable; herdr entities are not. Resolution maps each
spec entry to a live entity (or `None` → create).

The orchestrator maintains `state.json` (never hand-edited) mapping
logical names to herdr IDs, e.g. `ledger → w4`, `ledger.remote → w9:t4`.

Resolution order:

1. **State file** — if the mapped ID still exists in the snapshot, match.
2. **Spec `match` hints** — recover identity after a herdr restart.
3. **Heuristic fingerprint** (cwd + titles + pane count + split shape) —
   opt-in per workspace; off by default because false positives lead to
   destructive ops.
4. **Ambiguity** — multiple equally good matches → plan emits
   `AMBIGUOUS <name>` and does nothing for that entry unless
   `on_ambiguous = "adopt" | "new"` is set.

`orch import` inverts the problem: adopt the live server into a fresh
`layout.toml` + `state.json`. This is the bootstrap for "an existing
herdr server" without reorganizing first.

## 5. Reconciliation

```
snapshot → resolve identity → diff → plan → permission check → execute → verify
```

- **plan** lists concrete ops with before/after, e.g.
  `MOVE-PANE w9:p5 → w4 --new-tab --label 2`,
  `RENAME-TAB w1:t7 "1" → "sync-models"`.
- **apply** fails closed: ops before a denial run, the rest abort, and
  the report names the rule that blocked each one.
- **verify** re-snapshots and reports residual drift.

## 6. Permission model

Declarative rules evaluated per planned operation; most-specific match
wins. Three dimensions — **action**, **scope**, **verdict**.

### Actions

`workspace.{create,rename,close,focus}` ·
`tab.{create,rename,move,close,focus}` ·
`pane.{move,split,close,focus,send-keys}` ·
`agent.{prompt,keys,rename}` · `state.write`

`tab.move` is a *virtual* action: a plan-level tab relocation expands to
several `pane.move` calls but is authorized once, at plan level. Moving
a foreign pane into the tab is `pane.move`, not covered by `tab.move` —
deliberate.

### Rules (`permissions.toml`)

```toml
version = 1

[default]
"*" = "deny"
"workspace.create" = "allow"   # cheap and reversible
"tab.create"       = "allow"
"state.write"      = "allow"

[workspace.ledger]
"tab.rename"      = "allow"
"tab.move"        = "ask"      # confirm any move touching ledger
"workspace.close" = "deny"     # never close ledger, even if drifted

[workspace.ledger.tab.remote]
"pane.close"   = "deny"
"agent.prompt" = "ask"

[workspace."scratch-*"]
"*" = "ask"                    # scratch workspaces: everything gated
```

Verdicts: `allow` / `deny` / `ask` (interactive prompt; degrades to
`deny` in `--non-interactive` mode so agent-invoked runs fail closed
rather than hang).

Scopes: `[workspace.<logical>]`, `[workspace.<logical>.tab.<logical>]`,
`[...pane.<i>]`; globs allowed. Specificity: pane > tab > workspace >
default; first match at the most specific level wins; `"*"` is the
fallback at that level; `deny` wins any tie.

Two hard invariants:

- `*.close` can never be elevated from `deny`, not even by `--force`
  (which only upgrades `ask`).
- Nothing here can be overridden by CLI flags — the only escape is
  editing the rules.

### Why per-action verdicts

The orchestrator is expected to be callable *from* agents. Per-action
verdicts let you grant a pi session `tab.move` + `workspace.create` for
its own repo while keeping `agent.prompt`, `*.close`, and
`pane.send-keys` locked. Granularity is the point of the service.

## 7. CLI

```
orch plan                  # dry-run drift report; exit 1 if any op would be denied
orch apply [--resume]      # reconcile; permission-checked; resumable after interruption
orch open <name>           # ensure workspace + tabs per spec, focus it
orch status                # human-readable drift, no plan
orch import [--out DIR]    # adopt live layout into layout.toml + state.json
orch move tab <logical> --to <workspace>   # manual ops, same permission engine
orch rename tab <logical> <label>
orch focus <workspace> [tab]
orch state repair          # re-resolve identities after herdr restart
```

Flags: `--spec`, `--config`, `--non-interactive`, `--force`, `--json`.

## 8. Implementation notes

- Python, matching the existing `herdr/plugins/*` in this repo.
- Shell out to the `herdr` CLI first; a socket client generated from
  `herdr api schema --json` is a later optimization behind one
  `HerdrClient` interface.
- The command builder encodes the mode-dependent `pane move` grammar
  (§2.7) rather than concatenating flags.
- No transactions in herdr: the plan is persisted before execution so an
  interrupted apply resumes instead of re-deriving (§7 `--resume`).
- Snapshot and restore focus around ops unless a `focus = true` op ran.

## 9. Milestones

1. **M1** — read-only core: snapshot normalize, `status`, `import`.
2. **M2** — planning: identity resolution + diff + plan rendering.
3. **M3** — apply: permission engine + executor (create/rename/move).
4. **M4** — close + interactive ask + `--non-interactive` + resume.
5. **M5** — `orch` as a callable tool from pi sessions.

## 10. Open questions

- Remote targets (`herdr --remote <ssh>`)? Probably eventually; hide the
  target behind `HerdrClient` from day one.
- Tab reordering may require focus-juggling (if the API allows it at
  all) — defer to M3 experiments.
- Prompting an agent another session started: in scope? Default yes,
  always `ask`.
- Per-repo `herdr.toml` merged into the central spec (repo declares its
  tabs, orchestrator assigns the workspace)? Attractive for
  `orch open .`; deferred until the central spec is proven.
