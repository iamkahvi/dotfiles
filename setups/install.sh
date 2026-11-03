#!/usr/bin/env bash
#
# Dotfiles entry point for every machine.
#
#   setups/install.sh [--dry-run] [--links-only] [--packages-only]
#
# 1. Detect DOTFILES_PLATFORM (macos, omarchy, ubuntu) and DOTFILES_PROFILE
#    (personal, work) with zsh/.zshenv. ~/.zshenv.local can override both.
# 2. Run setups/packages/$DOTFILES_PLATFORM.sh.
# 3. Link common files, then platform files, then profile files.
#
# See docs/machine-branching-plan.md for the labels and the file tree.

set -euo pipefail

DOTFILES="${DF_HOME:-$HOME/dotfiles}"
DRY_RUN=0
RUN_PACKAGES=1
RUN_LINKS=1

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --links-only) RUN_PACKAGES=0 ;;
    --packages-only) RUN_LINKS=0 ;;
    -h | --help)
      sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "$DOTFILES" ]]; then
  echo "dotfiles not found at $DOTFILES. Clone the repo there, or set DF_HOME." >&2
  exit 1
fi

# --------------------------------------------------------------------------
# Axes. zsh/.zshenv is bash-compatible, so bash and zsh share one detection.
# --------------------------------------------------------------------------
# shellcheck source=../zsh/.zshenv
source "$DOTFILES/zsh/.zshenv"

if [[ "$DOTFILES_PLATFORM" == unknown ]]; then
  echo "cannot detect the platform. Set DOTFILES_PLATFORM in ~/.zshenv.local." >&2
  exit 1
fi

echo "dotfiles:  $DOTFILES"
echo "platform:  $DOTFILES_PLATFORM"
echo "profile:   $DOTFILES_PROFILE"
[[ "$DRY_RUN" -eq 1 ]] && echo "mode:      dry run (no change)"
echo

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
# run <cmd...>: skip the command in a dry run. The caller prints what it does.
run() {
  [[ "$DRY_RUN" -eq 1 ]] || "$@"
}

resolve() {
  # readlink -f is absent on older macOS. python3 is on every target machine.
  python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

# backup_and_link <source> <target>
# Backs up an existing target, then links. Never replaces a link silently.
backup_and_link() {
  local source_file="$1" target_file="$2"

  if [[ ! -e "$source_file" ]]; then
    printf '  missing source, skip: %s\n' "$source_file"
    return
  fi

  if [[ -L "$target_file" && "$(resolve "$target_file")" == "$(resolve "$source_file")" ]]; then
    printf '  ok:      %s\n' "$target_file"
    return
  fi

  run mkdir -p "$(dirname "$target_file")"

  if [[ -e "$target_file" || -L "$target_file" ]]; then
    local backup="$target_file.pre-dotfiles-$(date +%Y%m%dT%H%M%S%z)"
    printf '  backup:  %s -> %s\n' "$target_file" "$backup"
    run mv "$target_file" "$backup"
  fi

  printf '  link:    %s -> %s\n' "$target_file" "$source_file"
  run ln -s "$source_file" "$target_file"
}

# link <repo-relative source> <target>
link() {
  backup_and_link "$DOTFILES/$1" "$2"
}

# --------------------------------------------------------------------------
# Packages
# --------------------------------------------------------------------------
if [[ "$RUN_PACKAGES" -eq 1 ]]; then
  pkg_script="$DOTFILES/setups/packages/$DOTFILES_PLATFORM.sh"
  echo "== packages ($DOTFILES_PLATFORM)"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  would: bash $pkg_script"
  else
    bash "$pkg_script"
  fi
  echo
fi

[[ "$RUN_LINKS" -eq 1 ]] || exit 0

# --------------------------------------------------------------------------
# Links: common
# --------------------------------------------------------------------------
echo "== links: common"
link zsh/.zshenv "$HOME/.zshenv"
link zsh/.zshrc "$HOME/.zshrc"
link vim/.vimrc "$HOME/.vimrc"
link vim/init.lua "$HOME/.config/nvim/init.lua"
link git/config "$HOME/.config/git/config"
link tmux/.tmux.conf "$HOME/.tmux.conf"
link yazi/yazi.toml "$HOME/.config/yazi/yazi.toml"
link yazi/keymap.toml "$HOME/.config/yazi/keymap.toml"
link yazi/package.toml "$HOME/.config/yazi/package.toml"
link herdr/config.toml "$HOME/.config/herdr/config.toml"
link agents/AGENTS.md "$HOME/.pi/agent/AGENTS.md"
link scripts/tmux-sessionizer "$HOME/.local/bin/tmux-sessionizer"
echo

# --------------------------------------------------------------------------
# Links: platform
# --------------------------------------------------------------------------
echo "== links: $DOTFILES_PLATFORM"
case "$DOTFILES_PLATFORM" in
  macos)
    link ghostty/config "$HOME/.config/ghostty/config"
    link ghostty/config-macos "$HOME/.config/ghostty/platform.conf"
    link ghostty/ghostty-workspace "$HOME/.local/bin/ghostty-workspace"
    link aerospace/.aerospace.toml "$HOME/.aerospace.toml"
    link hammerspoon/init.lua "$HOME/.hammerspoon/init.lua"
    link karabiner/karabiner.json "$HOME/.config/karabiner/karabiner.json"
    link webstorm/webstorm "$HOME/.local/bin/webstorm"
    link vscode/settings.json "$HOME/Library/Application Support/Code/User/settings.json"
    link vscode/keybindings.json "$HOME/Library/Application Support/Code/User/keybindings.json"
    ;;
  omarchy)
    link ghostty/config "$HOME/.config/ghostty/config"
    link ghostty/config-omarchy "$HOME/.config/ghostty/platform.conf"
    link hypr/bindings.lua "$HOME/.config/hypr/bindings.lua"
    link hypr/input.lua "$HOME/.config/hypr/input.lua"
    link hypr/looknfeel.lua "$HOME/.config/hypr/looknfeel.lua"
    link scripts/toggle-centered-master "$HOME/.local/bin/toggle-centered-master"
    link vscode/settings.json "$HOME/.config/Code/User/settings.json"
    link vscode/keybindings.json "$HOME/.config/Code/User/keybindings.json"
    ;;
  ubuntu)
    echo "  (CLI only. No platform links.)"
    ;;
esac
echo

# --------------------------------------------------------------------------
# Links: profile
# --------------------------------------------------------------------------
echo "== links: $DOTFILES_PROFILE"
link "pi/settings.$DOTFILES_PROFILE.json" "$HOME/.pi/agent/settings.json"
link "tmux/sessionizer.$DOTFILES_PROFILE.yaml" "$HOME/.config/tmux-sessionizer/sessionizer.yaml"

case "$DOTFILES_PROFILE" in
  personal)
    link pi/models.json "$HOME/.pi/agent/models.json"
    [[ "$DOTFILES_PLATFORM" == macos ]] && link scripts/blockit "$HOME/.local/bin/blockit"
    ;;
  work)
    [[ "$DOTFILES_PLATFORM" == macos ]] && link finicky/.finicky.js "$HOME/.finicky.js"
    # Work guidance for agents. Untracked. pi appends it to the system prompt.
    backup_and_link "$HOME/.config/agents/work-tools.md" "$HOME/.pi/agent/APPEND_SYSTEM.md"
    # The stack skill lives outside the repo on the work Mac.
    backup_and_link "$HOME/.claude/skills/stack" "$HOME/.pi/agent/skills/stack"
    ;;
esac
echo

# --------------------------------------------------------------------------
# herdr plugins. `herdr plugin link` keeps its own registry.
# --------------------------------------------------------------------------
if command -v herdr >/dev/null 2>&1; then
  echo "== herdr plugins"
  for plugin in "$DOTFILES"/herdr/plugins/*/; do
    printf '  plugin:  %s\n' "${plugin%/}"
    run herdr plugin link "${plugin%/}" >/dev/null 2>&1 || true
  done
  echo
fi

echo "Done. Open a new shell."
if [[ "$DOTFILES_PROFILE" == work && ! -r "$HOME/.zshenv.local" ]]; then
  echo "note: ~/.zshenv.local is absent. Add 'export DOTFILES_PROFILE=work' there, or the next shell is personal."
fi
