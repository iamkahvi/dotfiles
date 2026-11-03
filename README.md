# dotfiles

Config files for my macOS and Linux machines. One branch (`master`) for all machines.

Each file is the same on all machines, or it branches on one of two axes:

- Platform: `macos`, `omarchy`, or `ubuntu`. `zsh/.zshenv` detects it.
- Profile: `personal` or `work`. `~/.zshenv.local` sets `DOTFILES_PROFILE=work` on the work Mac.

`docs/machine-branching-plan.md` has the labels, the mechanisms, and the file tree.

## What's here

**Shell:** zsh (`zsh/.zshrc` common, `zsh/<platform>.zsh`, `zsh/work.zsh`)

**Terminal:** ghostty (`config` shared, `config-macos`, `config-omarchy`)

**Editors:** vim/neovim, vscode, webstorm

**Window management:** aerospace, hammerspoon, hyprland (Omarchy)

**Multiplexers:** tmux, herdr

**Agents:** `agents/AGENTS.md`, `pi/{common,personal,work}` packages, `pi/settings.{personal,work}.json`

**Other:** git, karabiner, finicky, scripts, yazi

**Legacy:** `legacy/` holds configs that no setup installs (fish, kitty, hyper, iterm2, i3, nginx, zellij, espanso).

## Shell tricks

Useful shortcuts worth committing to muscle memory.

### Line editing (works everywhere)

| Keys | What it does |
|---|---|
| `Ctrl+W` | Delete word before cursor (way faster than holding backspace) |
| `Ctrl+U` / `Ctrl+K` | Cut from cursor to start / end of line. `Ctrl+Y` pastes it back |
| `Ctrl+A` / `Ctrl+E` | Jump to start / end of line |
| `Alt+B` / `Alt+F` | Move back / forward one word |
| `Ctrl+X Ctrl+E` | Open current command in `$EDITOR` (already bound in zshrc) |
| `ESC .` or `Alt+.` | Insert last argument of previous command. Press repeatedly to cycle back |

### Quick operations

```sh
> file.txt                # truncate file without deleting (preserves permissions/ownership)
cp pf.conf{,.bak}         # brace expansion: copies pf.conf to pf.conf.bak
mv file.{txt,md}          # renames file.txt to file.md
mkdir -p project/{src,tests,docs}  # create multiple dirs at once
diff <(sort a.txt) <(sort b.txt)   # process substitution: diff sorted versions without temp files
command |& tee file.log   # pipe both stdout+stderr to screen AND file
```

### Process rescue

When you forgot to run something in tmux/screen and it's tying up your terminal:

```sh
Ctrl+Z    # suspend the process
bg        # resume it in background
disown    # detach from shell — survives logout/SSH disconnect
```

### History

| Shortcut | What it does |
|---|---|
| `sudo !!` | Re-run last command with sudo |
| `!$` | Last argument of previous command (expands on enter) |
| `fc` | Open previous command in `$EDITOR` for editing (portable, works in sh/ksh too) |

### Terminal recovery

```sh
reset     # fixes garbled terminal after accidentally catting a binary
```

## Setup

```sh
git clone https://github.com/iamkahvi/dotfiles ~/dotfiles

# work Mac only
echo 'export DOTFILES_PROFILE=work' >> ~/.zshenv.local

~/dotfiles/setups/install.sh --dry-run
~/dotfiles/setups/install.sh
```

`install.sh` detects the platform, runs `setups/packages/<platform>.sh`, then links common, platform, and profile files.
It backs up each file that it replaces as `<file>.pre-dotfiles-<timestamp>`.
`setups/omarchy.md` has the manual checks for Omarchy.
