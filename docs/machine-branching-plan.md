# Machine Branching Plan

Status: draft. No change is made yet.

## Goal

Keep one branch (`master`) for all machines.
Remove the `kp/work` branch after its changes move to `master`.
Each file is the same on all machines, or it branches on a known axis.

## Machines

| Machine             | Platform       | OS             | Profile    | User             | Status                                                      |
| ------------------- | -------------- | -------------- | ---------- | ---------------- | ----------------------------------------------------------- |
| Work Mac            | `macos`        | macOS          | `work`     | `kahvi`          | Active. This document was written here.                     |
| Personal Mac        | `macos`        | macOS          | `personal` | `iamkahvi`       | Confirmed.                                                  |
| Omarchy workstation | `omarchy`      | Linux (Arch)   | `personal` | `iamkahvi`       | Active. Set up from `setups/omarchy.md`.                    |
| Ubuntu server       | `ubuntu`       | Linux (Ubuntu) | `personal` | `iamkahvi`       | Active. Set up from `setups/install.sh` (verify). CLI only. |

There is no work Linux machine. Thus the `work` profile occurs only on the `macos` platform.

The user name is `iamkahvi` on personal machines and `kahvi` on the work Mac.
Thus a hardcoded home path works on some machines and breaks on others.
Rule: tracked files use `$HOME` or `~`. They do not use `/Users/<name>` or `/home/<name>`.
Known violations: `herdr/plugins/pi-panel/herdr-plugin.toml`, the `tec` line in `.zshrc`, `tmux/sessionizer.yaml` (kp/work), `pi/settings.json` (kp/work), and the `pi/skills/stack` and `pi/skills/tldr` symlinks.

The repo is public. Shopify-internal text in a `common` file is published. This applies to `pi/skills/tldr`. See its section. The work guidance from `AGENTS.md` moves to an untracked file. See the `agents/AGENTS.md` section.

## Branch Axes

There are two independent axes:

- Platform: `macos`, `omarchy`, or `ubuntu`. Read from `DOTFILES_PLATFORM`. `zsh/.zshenv` detects it. No setup is necessary.
- Profile: `personal` or `work`. Read from `DOTFILES_PROFILE`.

Platform is not the same as OS. OS has two values (macOS and Linux). Platform also splits Linux by distro, because Omarchy and Ubuntu install packages to different paths.

There is no separate OS axis. No config is shared by `omarchy` and `ubuntu` and absent on `macos`. If such config occurs, add `zsh/linux.zsh` and source it from both Linux platform files.

There is no desktop or server axis. The platform gives the same information:

- Each Mac is a desktop. GUI casks are in `mac_install.sh`.
- On Linux, only Omarchy has GUI apps. Omarchy supplies Hyprland, and `omarchy.md` adds Ghostty.
- `install.sh` installs only apt CLI tools. It is the Ubuntu server setup.

Zsh and the install script both use `DOTFILES_PLATFORM`.

### Profile Source

Each machine has one untracked file: `~/.zshenv.local`.

```sh
# ~/.zshenv.local on the work Mac (not in git)
export DOTFILES_PROFILE=work
export SHOPIFY_TALENT_TOKEN="..."
```

Personal machines do not need `~/.zshenv.local`. The default profile is `personal`.

A tracked `zsh/.zshenv` sources it and sets a default:

```sh
[[ -r "$HOME/.zshenv.local" ]] && source "$HOME/.zshenv.local"
export DOTFILES_PROFILE="${DOTFILES_PROFILE:-personal}"
if [[ -z "$DOTFILES_PLATFORM" ]]; then
  case "$OSTYPE" in
    darwin*) DOTFILES_PLATFORM=macos ;;
    *) case "$(. /etc/os-release 2>/dev/null; echo "$ID")" in
         arch)   DOTFILES_PLATFORM=omarchy ;;  # verify the ID on Omarchy
         ubuntu) DOTFILES_PLATFORM=ubuntu ;;
         *)      DOTFILES_PLATFORM=unknown ;;
       esac ;;
  esac
fi
export DOTFILES_PLATFORM
```

`~/.zshenv.local` can set `DOTFILES_PLATFORM` to override the detection.

Zsh reads `.zshenv` for each shell, including non-interactive shells.
Thus tmux, herdr, scripts, and ssh sessions all get the same profile.
This replaces `command = env WORK=1 ${SHELL} -l` in Ghostty.
The install script runs the same detection. Then it reads `DOTFILES_PLATFORM` and `DOTFILES_PROFILE`.

## Labels

| Label                          | Meaning                                                                  |
| ------------------------------ | ------------------------------------------------------------------------ |
| `common`                       | Same file on all machines.                                               |
| `macos` / `omarchy` / `ubuntu` | Install only on that platform.                                           |
| `personal` / `work`            | Install only on that profile.                                            |
| `branched: platform`           | One logical config. The content differs for some platforms. The tree entry names the mechanism (M1 to M5). |
| `branched: work`               | One logical config. The content differs for personal and work.           |
| `branched: platform+work`      | The content differs on both axes.                                        |

Examples:

- `branched: platform` with M1: `.zshrc` is linked on all platforms. The plugin loader sources `/usr/share/zsh/plugins/...` on `omarchy` and `$ZSH_CUSTOM/plugins/...` on `macos` and `ubuntu`.
- `branched: platform` with M3: Ghostty has one config on each platform. The install script links `config-macos` on `macos` and `config-omarchy` on `omarchy`. `ubuntu` gets none.
- Not branched: `hypr/` is `omarchy`. Only one platform installs it, and its content does not change.
| `local`                        | Not in git. Each machine has its own copy.                               |
| `legacy`                       | No current setup installs it. Delete it or keep it as an archive.        |

## Mechanisms

| ID | Mechanism | Use when |
|---|---|---|
| M1 | Runtime conditional | The file is a script (`zsh`, `sh`, `lua`). |
| M2 | Native optional include | The tool can include a second file that can be absent. |
| M3 | Install-time link selection | The whole file differs. The install script links the correct variant. |
| M4 | Install-time generation | The format has no include (JSON, YAML, Markdown), or the app writes to the file. The install script merges a base file and an overlay into a real file. |
| M5 | Untracked local file | Secrets and machine identity. |

Rule for M4: do not symlink generated files.
Exception: `pi/settings.json` uses M3 (a symlink) by decision, although pi writes to it. See its section.

## File Tree

```
dotfiles/
├── .gitignore                         common    add: .claude/, generated outputs
├── README.md                          common
├── aerospace/.aerospace.toml          macos
├── agents/AGENTS.md                   common    moved from the repo root. Linked to ~/.pi/agent/AGENTS.md.
├── espanso/                           legacy    not installed on work Mac
├── fish/                              legacy    has /Users/iamkahvi paths
├── ghostty/
│   ├── config                         branched: platform   M2   shared base. Includes the platform file.
│   ├── config-macos                   macos     platform file (M2)
│   ├── config-omarchy                 omarchy   new. Platform file (M2). Current `config` content.
│   ├── ghostty-workspace              macos     uses osascript
│   └── workspaces/                    macos
├── git/config                         branched: work   M2
├── hammerspoon/init.lua               macos     not linked on work Mac (copy exists)
├── herdr/
│   ├── config.toml                    common
│   ├── orchestrator/                  common
│   └── plugins/
│       ├── mru-spaces/                common
│       ├── mru-tabs/                  common    (kp/work)
│       ├── new-pi-tab/                common    devx path has an -x guard (kp/work)
│       ├── pi-panel/                  common    take run-pi.sh from kp/work
│       └── todo/                      common    (kp/work)
├── hyper/                             legacy
├── hypr/                              omarchy
├── i3/                                legacy
├── iterm2/                            legacy
├── karabiner/karabiner.json           macos     not linked on work Mac (copy exists)
├── kitty/                             legacy    linked on work Mac, verify use
├── nginx/                             legacy    kahvipatel.com sites. Not in use.
├── pi/
│   ├── extensions/
│   │   ├── clear-prompt/              common    (kp/work)
│   │   ├── copy-code/                 common    (kp/work)
│   │   ├── copy-prompt/               common    (kp/work)
│   │   ├── session-id-copy/           common    (kp/work)
│   │   ├── defuddle/                  common
│   │   ├── git-push-guard.ts          common
│   │   ├── pi-worktree-subagent/      common
│   │   ├── quick-notes.ts             common
│   │   ├── review.ts                  common
│   │   ├── session-export.ts          common
│   │   ├── gemini-thought-signatures.ts  personal  tailnet proxy
│   │   └── web-search/                personal  tailnet SearXNG. Rename index.ts.disabled to index.ts.
│   ├── models.json                    personal  tailnet provider. Work Mac has its own copy.
│   ├── search_sessions.sh             common
│   ├── settings.personal.json         branched: work   M3  linked to ~/.pi/agent/settings.json
│   ├── settings.work.json             branched: work   M3  linked to ~/.pi/agent/settings.json
│   └── skills/
│       ├── browser-mcp/               personal
│       ├── gccli/                     legacy
│       ├── gmcli/                     legacy
│       ├── loop/                      common
│       ├── review/                    common
│       ├── simplify/                  common
│       ├── sync-models/               personal  tailnet proxy
│       ├── textarea-decode/           work      quick.shopify.io
│       ├── stack -> /Users/kahvi/...  work      absolute symlink. Remove from git.
│       └── tldr/                      common    copy into the repo. Now a symlink to /Users/kahvi/.claude. Uses Shopify-only MCP servers.
├── scripts/
│   ├── blockit                        personal  osascript with an $EDITOR fallback
│   ├── immich-to-r2.sh                personal  verify if it runs on the server
│   ├── open-kitty-term.rb             legacy
│   ├── tmux-sessionizer               common
│   └── toggle-centered-master         omarchy   uses hyprctl
├── setups/
│   ├── install.sh                     ubuntu    apt CLI tools only. Becomes the ubuntu step.
│   ├── mac_install.sh                 macos     becomes the macos step
│   ├── omarchy.md                     omarchy
│   ├── setup_linux.md                 legacy    Ubuntu laptop dual-boot guide (i3, X11)
│   └── 2023_setup.md                  legacy
├── tmux/
│   ├── .tmux.conf                     common
│   ├── sessionizer.yaml               branched: work   M4
│   ├── tmux-sessions.sh               common
│   └── session-toggle-shortcut.md     common
├── vim/{.vimrc,init.lua}              common
├── vscode/                            common    not linked on work Mac
├── webstorm/webstorm                  macos     uses `open -na`
├── yazi/                              common
├── zellij/                            legacy    linked on work Mac. Omarchy guide says use herdr.
└── zsh/
    ├── .zshenv                        common    new. Sets the profile and the platform.
    ├── .zshrc                         branched: platform+work   M1
    ├── macos.zsh                      macos     new. Split from .zshrc.
    ├── ubuntu.zsh                     ubuntu    new. Split from .zshrc.
    └── work.zsh                       work
```

Local files (not in git, M5):

| File | Machines | Purpose |
|---|---|---|
| `~/.zshenv.local` | work Mac | `DOTFILES_PROFILE=work` and secrets |
| `~/.config/agents/work-tools.md` | work Mac | work guidance for agents. Linked to `~/.pi/agent/APPEND_SYSTEM.md`. |
| `~/.gitconfig` | work Mac | managed by `dev` |
| `~/.claude/CLAUDE.md` | all | Claude Code rules. Imports `agents/AGENTS.md`, and `work-tools.md` on the work Mac. |
| `~/.pi/agent/agents/ae-*.md` | work Mac | subagent files. They set `model: claude-sonnet-4-5`, which is a work model ID. |
| `~/.pi/agent/models.json` | work Mac | local providers. Can hold API keys. Never link. |

## Details for Branched Items

### zsh/.zshrc (branched: platform+work, M1)

`.zshrc` keeps the common part. At the end, it sources the platform file, then the profile file:

```sh
[[ -r "$DF_HOME/zsh/$DOTFILES_PLATFORM.zsh" ]] && source "$DF_HOME/zsh/$DOTFILES_PLATFORM.zsh"
[[ "$DOTFILES_PROFILE" == work ]] && source "$DF_HOME/zsh/work.zsh"
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
```

| Content                                                         | Destination                                                |
| --------------------------------------------------------------- | ---------------------------------------------------------- |
| iCloud path, Tailscale.app alias, Sublime path, `pbcopy` branch | `macos.zsh`                                                |
| Plugin and prompt loader (path list, next table)                | `.zshrc` (common)                                          |
| `batcat` and `fdfind` aliases, if the short name is absent      | `ubuntu.zsh`                                               |
| `/opt/dev`, chruby, `devx` aliases, `tec` init                  | `work.zsh`                                                 |
| `pnpm` (`~/Library/pnpm`), `mise activate`                      | `work.zsh`, or `common` with a `command -v` guard. Decide. |
| `eval "$(try init ~/src/tries)"`                                | Decide: `work.zsh` or common with a guard.                 |
| `SHOPIFY_TALENT_TOKEN`                                          | `~/.zshenv.local` (M5)                                     |
| `zoxide init`                                                   | Common. Add a `command -v` guard.                          |

The Oh My Zsh plugin load order is different on `omarchy` and on the other platforms.
Syntax highlighting must load last on both.

The common loader checks a list of paths for each item. The first path that exists wins.
`mac_install.sh` and `install.sh` clone the plugins and Pure into the same paths. Thus macOS and Ubuntu share one column:

| Item | omarchy (Arch packages) | macos and ubuntu (git clone) |
|---|---|---|
| Oh My Zsh | `/usr/share/oh-my-zsh` | `~/.oh-my-zsh` |
| zsh-autosuggestions | `/usr/share/zsh/plugins/zsh-autosuggestions/` | `$ZSH_CUSTOM/plugins/zsh-autosuggestions/` |
| zsh-syntax-highlighting | `/usr/share/zsh/plugins/zsh-syntax-highlighting/` | `$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/` |
| Pure prompt | `/usr/share/zsh/functions/Prompts/` | `~/.zsh/pure` |
| fzf key bindings | `/usr/share/fzf/key-bindings.zsh` | macOS: `~/.fzf.zsh`. Ubuntu apt: `/usr/share/doc/fzf/examples/key-bindings.zsh` (verify). |

The `$ZSH_CUSTOM` plugins load through `plugins=(...)`. The Arch plugins load with `source`.
The `master` change removed the two plugins from `plugins=(...)`. That breaks macOS and Ubuntu. The loader fixes it.

### ghostty (branched: platform, M2)

Decision: one shared `ghostty/config`, plus one platform file for each platform.

- Move the current `ghostty/config` (Omarchy theme, fonts, epoll) to `ghostty/config-omarchy`.
- `ghostty/config` keeps only settings for both platforms. It ends with an optional include:

```
config-file = ?"~/.config/ghostty/platform.conf"
```

- The install script links `config` to `~/.config/ghostty/config` on `macos` and `omarchy`.
- The install script links `config-$DOTFILES_PLATFORM` to `~/.config/ghostty/platform.conf`.
- The `ubuntu` platform skips Ghostty. The label `branched: platform` does not mean that Ubuntu gets a variant.

An absolute path avoids one question: does Ghostty resolve a relative path against the symlink or against its target? Verify that `~` expands in `config-file`.

Candidates for the shared base (both files have them now, or only Omarchy has them):

- `keybind = shift+enter=csi:13;2u` and `keybind = alt+shift+enter=csi:13;4u`. Only Omarchy has them. TUIs (pi, herdr) need them to tell Shift+Enter from Enter. Verify on macOS.
- `resize_split` keybinds, `cursor-style`, `mouse-scroll-multiplier`, `confirm-close-surface`.

Remove the `command = env WORK=1 ...` line. `.zshenv` sets the profile.

### git/config (branched: work, M2)

Git reads `~/.config/git/config` first. Then it reads `~/.gitconfig`, and the later value wins.
On the work Mac, `dev` manages `~/.gitconfig` (work email, `include.path` to the dev gitconfig, quick credential helper).
Plan:

- Link `git/config` to `~/.config/git/config` on all machines.
- On the work Mac, `~/.gitconfig` stays local and overrides `user.email`.
- On personal machines, `~/.gitconfig` is absent.

Fix: `install.sh` and `mac_install.sh` link `git/.gitconfig`. That file does not exist. The real file is `git/config`.

### pi/settings.json (branched: work, M3)

Decision: option A. Keep one full file for each profile. The install script links one of them:

```sh
ln -sfn "$DOTFILES/pi/settings.$DOTFILES_PROFILE.json" "$HOME/.pi/agent/settings.json"
```

`pi/settings.personal.json` (from `master`):

```json
{
  "defaultProvider": "tailscale-ai",
  "defaultModel": "gpt-5.6-terra",
  "defaultThinkingLevel": "high",
  "theme": "system",
  "packages": [
    "npm:pi-ask-user",
    "~/dotfiles/pi/common",
    "~/dotfiles/pi/personal"
  ],
  "extensions": ["-extensions/omarchy-system-theme.ts"]
}
```

`pi/settings.work.json` (from the live work Mac file, not from the stale `kp/work` copy):

```json
{
  "defaultProvider": "anthropic-250k-prefer-using-this-one",
  "defaultModel": "claude-opus-5-5",
  "defaultThinkingLevel": "high",
  "theme": "system",
  "showCacheMissNotices": true,
  "npmCommand": ["pnpm", "--config.node-version=22.23.4"],
  "packages": ["~/dotfiles/pi/common", "~/dotfiles/pi/work"],
  "skills": ["-skills/graphite", "-~/.agents/skills/stack"]
}
```

Splits between the profiles:

| Key | Personal | Work |
|---|---|---|
| `defaultProvider`, `defaultModel` | tailnet proxy | Shopify proxy |
| `packages` (npm) | `pi-ask-user` | none. shop-pi-fy supplies `ask`. |
| `packages` (local) | `pi/common`, `pi/personal` | `pi/common`, `pi/work` |
| `npmCommand` | none | `pnpm` with a Node pin |
| `skills` exclusions | none | hide skills that work tools install in `~/.agents/skills` |
| `showCacheMissNotices` | none | `true` |
| `extensions` exclusion | `omarchy-system-theme.ts` | none |

Both files contain `theme` and `defaultThinkingLevel`. Change these 2 keys in both files.

Removed: `npm:pi-web-search`. `pi/personal/extensions/web-search` (tailnet SearXNG) supplies `web_search`. Two `web_search` tools would conflict.

Removed keys: the `extensions` path list (the package folders replace it), `hideThinkingBlock` (default value), and `lastChangelogVersion` (pi state).

Omarchy theme: Omarchy copies `omarchy-system-theme.ts` into `~/.pi/agent/extensions` (`install/config/pi.sh`). It calls `ctx.ui.setTheme("light"|"dark")` when the Omarchy theme changes. pi saves that value to `settings.json`, and the link writes it into `settings.personal.json`. Fix:

- Set `"theme": "system"` in both files. This is the pi default. It follows the terminal colors.
- Exclude `omarchy-system-theme.ts` in the personal file. The entry has no effect on other machines.
- Verify that `system` follows Ghostty on Omarchy after a theme change.

Known costs:

- pi writes through the symlink into the repo. `/model`, a thinking-level change, and each pi update (`lastChangelogVersion`) make `git status` dirty. Commit the change, or discard it with `git checkout`.
- pi writes only the changed keys, but it writes the whole file again. Format the files as pi writes them, so that the first write does not change the format.

Verify:

- `-~/.agents/skills/stack` works as an exact exclusion. If not, keep it in a form with no `/Users/kahvi` path.
- A local package with no `package.json` loads its `extensions/` and `skills/` folders.
- The provider ID `anthropic-250k-prefer-using-this-one` is safe to publish. It is not a secret, but it shows the name of an internal proxy provider.

Work Mac migration:

1. The live `~/.pi/agent/settings.json` is a real file. Copy its values into `settings.work.json`, then replace the file with the link.
2. Delete the 4 extension symlinks that you made by hand in `~/.pi/agent/extensions` (`clear-prompt`, `copy-code`, `copy-prompt`, `session-id-copy`). `pi/common` supplies them.
3. Delete the 12 links in `~/.pi/agent/skills` that point to `~/.agents/skills`. pi already scans `~/.agents/skills`, so each of these skills loads two times and gives a collision warning.
4. Remove the npm leftovers `@plannotator` and `pi-emote` from `~/.pi/agent/npm`. No settings file lists them.
5. Delete the expired `ollama` provider (Shopify proxy key, expired Feb 2026) from the local `~/.pi/agent/models.json`.

`setups/omarchy.md` links `pi/settings.json`. Change it to `pi/settings.personal.json`.

### pi state (never track)

pi and other tools write these paths in `~/.pi/agent`. Do not link them and do not copy them into the repo:

`auth.json`, `trust.json`, `models-store.json`, `sessions/`, `npm/`, `git/`, `llm-catalog/`, `bin/`, `config/`, `chrome-devtools.json`, `*.lock`, `settings.json.bak.*`.

Add the same names under `pi/` to `.gitignore` (for example `pi/auth.json` and `pi/sessions/`). This stops an accidental copy from going into a commit.

No split now: `keybindings.json`, `mcp.json`, `prompts/`, and `themes/` do not exist on the work Mac.

### pi/models.json (personal)

Install only on personal machines. The work Mac keeps its local copy.

### pi/skills and pi/extensions (branched: work, M3)

Each label gets one folder. Each folder is a local pi package with the conventional `extensions/` and `skills/` subfolders:

```
pi/common/{extensions,skills}/
pi/personal/{extensions,skills}/
pi/work/{extensions,skills}/
```

Each profile settings file lists `pi/common` and its own folder in `packages`. To add an item, put it in a folder. Do not edit the settings files.
`stack` points to `~/.claude/skills`, which is outside the repo. Remove it from git. On the work Mac, the install script makes the link.

Decision: `tldr` is `common`. It now points to `/Users/kahvi/.claude/skills/tldr`, which does not exist on personal machines. Copy `SKILL.md` into `pi/common/skills/tldr/`.
The skill calls `slack-mcp` and `incident-dashboard-mcp`. Those are Shopify servers, so the skill cannot run on personal machines. Decide: keep it `common` anyway, or set it to `work`.

### agents/AGENTS.md (common)

Decision: one `AGENTS.md` for all machines. It does not branch, and it does not refer to work files.

#### Problem: the file loads two times

pi loads context files from the agent directory, the working directory, and each parent directory.
Now `~/AGENTS.md` links to `~/dotfiles/AGENTS.md`, and the repo root also has `AGENTS.md`. In a dotfiles worktree, pi loads both files.
The two worktrees are on different branches. Thus one session got the `master` rules and the `kp/work` rules together. These rules conflict: "run `gt restack`" and "Graphite is retired".
Also, `~/AGENTS.md` applies only below `~`. It does not apply in `/tmp` or `/opt`.

#### Fix

1. Move `AGENTS.md` from the repo root to `agents/AGENTS.md`. pi then does not load it as project context in the repo.
2. Delete `CLAUDE.md` from the repo root. Claude Code v2.1.277 and later read `AGENTS.md` directly, so the symlink is not necessary.
3. Link `agents/AGENTS.md` to `~/.pi/agent/AGENTS.md` on all machines. pi loads this file in all directories.
4. Delete the links `~/AGENTS.md` and `~/CLAUDE.md`.
5. For Claude Code, add `@~/dotfiles/agents/AGENTS.md` to the local `~/.claude/CLAUDE.md`. On the work Mac, also add `@~/.config/agents/work-tools.md`.

Claude Code rules that affect this plan:

- Claude Code reads `AGENTS.md` only from the working directory and its parents. It has no user-level `AGENTS.md`. Thus it does not find `~/.pi/agent/AGENTS.md`. The import in step 5 is necessary.
- If a `CLAUDE.md`, `.claude/CLAUDE.md`, or `CLAUDE.local.md` is on the path, Claude Code reads no `AGENTS.md`. `~/.claude/CLAUDE.md` does not count.
- Now `~/CLAUDE.md` is on the path for each repo below `~`. Thus Claude Code ignores project `AGENTS.md` files in those repos. Step 4 fixes this.
- Imports in `~/.claude/CLAUDE.md` load with no approval dialog. `@~/...` paths are supported.

Optional: add a short root `AGENTS.md` with rules for work on this repo only. For example: "Read `docs/machine-branching-plan.md` first."

#### Work guidance (M5)

The work guidance goes to an untracked file: `~/.config/agents/work-tools.md`. It is not in any repo.
On the work Mac, the install script links it to `~/.pi/agent/APPEND_SYSTEM.md`, if the file exists.
pi adds `APPEND_SYSTEM.md` to the system prompt. pi loads it in addition to `AGENTS.md`. Personal machines do not have the file.

Limit: a project `.pi/APPEND_SYSTEM.md` replaces the agent-directory file. pi does not combine them. World has no such file now.

Move these parts of the `kp/work` `AGENTS.md` to `work-tools.md`:

| `kp/work` lines | Content |
|---|---|
| 57 | Delta (`dt`) for shop/world. `gs`, `gt`, Gitstream, Meteorite, and Graphite are retired. The `stack` skill. |
| 58 | "If I do not name a tool, use the table." Put it after the table. Now it says "above", but the table is below it. |
| 66–86 | Tools table, Tool Gateway in codemode |
| 88–91 | BigQuery |
| 95 (part) | `wg -l` |

`agents/AGENTS.md` keeps a generic Git rule: "Use plain `git` and `gh`." It also keeps `rg -l` and `git grep -l`.

Also decide: the `kp/work` text removes some `master` sections (for example, "Conventions" and "Code Review"). Decide if those sections stay.

### tmux/sessionizer.yaml (branched: work, M4)

Only `search_dirs` and `pins` differ.
Option A: generate the file from a base file and a profile overlay with `yq`.
Option B: make `scripts/tmux-sessionizer` read a second optional file, `sessionizer.local.yaml`. This option removes the generation step.

### setups (branched: platform+work)

Make one entry point, `setups/install.sh`. It detects the platform and runs one package step:

```
setups/
├── install.sh          detect platform, then run the steps below
├── packages/macos.sh   from mac_install.sh (brew, casks)
├── packages/omarchy.sh from omarchy.md (omarchy pkg)
└── packages/ubuntu.sh  from the current install.sh (apt, git clones)
```

Use the `backup_and_link` function from `omarchy.md`.
After the package step, `install.sh` does these steps:

1. Link `common` files.
2. Link `$DOTFILES_PLATFORM` files.
3. Link `$DOTFILES_PROFILE` files.
4. Generate M4 files.

Keep `omarchy.md` as prose for manual checks only.

### Ubuntu server items

- `pi`: verify if pi runs on the server. If yes, the personal `settings` overlay works there. The tailnet proxy must be reachable.
- `herdr`: verify if herdr runs on the server. If no, use tmux only.

## Cleanup Before the Move

1. Remove `SHOPIFY_TALENT_TOKEN` from `kp/work` commit `bf20143`. Put it in `~/.zshenv.local`.
2. Delete the orphan commit `9dc23ba` with `git reflog expire --expire=now --all` and `git gc --prune=now`.
3. Remove `.claude/settings.local.json` from git. Add `.claude/` and the pi state names to `.gitignore`.
4. Remove the absolute symlinks in `pi/skills/` from git.
5. Move the work guidance out of `AGENTS.md` to `~/.config/agents/work-tools.md`. Do this before a `kp/work` commit with `AGENTS.md` goes to `master`.
6. Decide which `legacy` items to delete.

Known public data on `master` that is not secret: the tailnet name `tail37572.ts.net` and `100.88.174.104`. Optional: read them from environment variables.

## Migration Order

1. Cleanup (previous section).
2. Add `zsh/.zshenv` and `~/.zshenv.local`. Split `.zshrc`.
3. Move the common `kp/work` commits to `master` with cherry-pick.
4. Make the split files (pi settings, sessionizer, ghostty). Move `AGENTS.md` to `agents/AGENTS.md` and fix the links.
5. Write the new `setups/install.sh`. Test it on each machine with a dry-run flag. Test the Ubuntu server last, because its paths are the least known.
6. Move `~/dotfiles` on the work Mac to `master`. Delete `kp/work`, `work`, `dotfiles-work`, `dotfiles-main`, and `dotfiles-master`.

## Open Questions

- Ubuntu server: which version?
- Ubuntu server: which tools run there (pi, herdr, nvim, yazi, tmux)?
- Ubuntu server: does `scripts/immich-to-r2.sh` run there?
- `pi/skills/tldr`: keep it `common`, or set it to `work`? It needs Shopify-only MCP servers.
- Legacy items: delete them from `master`, or keep them? Git history keeps them after a delete.
- Do `pnpm`, `mise`, and `try` go in `work.zsh` or in common with a guard?
- Is GNU stow (`kp/using-stow`) better than a link script for M3?
