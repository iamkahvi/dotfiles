# TODO

Open Vim in a new, left-most `TODO` tab in the current Herdr workspace.
The other tabs keep their relative order.

Bound to `prefix+d` (`Ctrl+a`, then `d`) in `herdr/config.toml`, invoking
`kahvi.todo.open`.

The action uses the focused pane's current directory:

- Inside a Git repository: `<repo-root>/kp_scratch/TODO.md`.
- Inside a Git worktree: `<worktree-root>/kp_scratch/TODO.md`.
- Outside Git: `<current-directory>/TODO.md`.

Creates `kp_scratch/` if needed. The global `~/.gitignore_global` rule already
ignores that directory on this machine. Existing notes are left intact; a new
`TODO.md` is written when you save in Vim. Quitting Vim closes the tab. Each
invocation opens a new tab.

Requires Python 3, Git, and Vim on `PATH`.

## Install

    herdr plugin link ~/dotfiles/herdr/plugins/todo
    herdr server reload-config

## Test

    python3 -m unittest discover -s ~/dotfiles/herdr/plugins/todo -p 'test_*.py'
