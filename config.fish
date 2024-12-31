if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -x DF_HOME $HOME/dotfiles

# git
abbr -a -- gst 'git status'

# single key
abbr -a -- c clear
abbr -a -- h history
abbr -a -- l 'ls -lah'
abbr -a -- - 'cd -'

# better ls
abbr -a -- la 'ls -lah'
abbr -a -- ldot 'ls -ld .*'
abbr -a -- ll 'ls -lGFh'
abbr -a -- lsa 'ls -aGF'

# quick nav
abbr -a -- fconf 'cd $__fish_config_dir'
abbr -a -- dot 'cd $DF_HOME'

# date/time
abbr -a -- ds 'date +%Y-%m-%d'
abbr -a -- ts 'date +%Y-%m-%dT%H:%M:%SZ'

# Create directories with `-p` option
function mkdir
    command mkdir -p $argv
end

# Show PATH as a newline-separated list
function showp
    echo $PATH | tr ' ' '\n'
end

# Edit .zshrc
function configz
    vim ~/.zshrc
end

# Edit .vimrc
function configv
    vim ~/.vimrc
end

# Alias vim to nvim
function vim
    nvim $argv
end

# Alias python to python3
function python
    python3 $argv
end

# Run Tailscale application
function tailscale
    /Applications/Tailscale.app/Contents/MacOS/Tailscale $argv
end

set -Ux PAGER less
set -Ux EDITOR nvim
set -Ux VISUAL code

set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"

function mkdir
    command mkdir -p $argv
end

function kahvi
    echo hello kahvi
end

function testarg
    echo $argv
end

function fh
    commandline (history | fzf +s | sed 's/ *[0-9]* *//')
end

function ff
    set file (find $argv -path '*/\.*' -prune -o -type f -print 2>/dev/null | fzf --preview 'cat {}' +m)
    vim $file
end

function set_editor
    if test -n "$SSH_CONNECTION"
        set -Ux EDITOR vim
    else
        set -Ux EDITOR nvim
    end
end

set_editor

fish_add_path /opt/homebrew/bin

fish_add_path /Users/iamkahvi/.local/bin

fish_add_path $HOME/.bun/bin

fish_add_path $HOME/.deno/bin

zoxide init fish | source

if test (uname) = "Darwin"
    # Commands for macOS
    echo "Running on macOS"
else if test (uname) = "Linux"
    # Commands for Linux
    echo "Running on Linux"
else
    # Commands for other OS
    echo "Not running on macOS"
end

# not totally sure if this works
function import_zsh_history
    awk -F ';' '{print $2}' ~/zsh_history_backup | while read -l cmd
        if test -n "$cmd"
            set timestamp (date +%s)
            echo -e "- cmd: $cmd\n  when: $timestamp" >> ~/fish_history_backup
        end
    end
    echo "Zsh history imported into Fish."
end

function check_command
    if type -q $argv
        echo "$argv is installed"
    else
        echo "$argv is not installed"
    end
end

check_command fzf
check_command bat
check_command zoxide
check_command nvim
