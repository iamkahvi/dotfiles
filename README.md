# dotfiles

Config files for my macOS and Linux machines.

## What's here

**Shells:** fish, zsh

**Terminals:** ghostty, kitty, hyper, iterm2

**Editors:** vim/neovim, vscode, webstorm

**Window management:** aerospace, hammerspoon, i3

**Multiplexers:** tmux, zellij

**Other:** git, karabiner, nginx, scripts, pi-extensions, yazi

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

```
# macOS
setups/mac_install.sh

# Linux
setups/install.sh
```
