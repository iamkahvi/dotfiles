# Tmux Recent Session Toggle Shortcut

## Goal
Add a fast keyboard shortcut to switch between recently opened tmux sessions.

## Recommended implementation
Use two shortcuts:

1. **A/B toggle** between current and previous session (built-in tmux behavior).
2. **MRU jump** to the most recently attached session that is not current.

This gives you both:
- instant back-and-forth toggling,
- and quick navigation when more than two sessions are active.

## Tmux config
Add these lines to `tmux/.tmux.conf`:

```tmux
# Toggle to previously active session (no prefix)
bind-key -n C-g run-shell 'tmux switch-client -l 2>/dev/null || tmux display-message "No previous session"'

# Go to most recently attached session that is not current (no prefix)
bind-key -n C-S-g run-shell '
  current="$(tmux display-message -p "#{session_name}")"
  target="$(tmux list-sessions -F "#{session_name} #{session_last_attached}" \
    | sort -k2,2nr \
    | awk -v cur="$current" "$1 != cur { print $1; exit }")"
  [ -n "$target" ] && tmux switch-client -t "$target"
'
```

## How it works

### `C-g` (`switch-client -l`)
- Uses tmux’s built-in “last session” pointer.
- Behavior: toggles between the current session and the one you last used.
- This is the fastest and most reliable way to bounce between two sessions.

### `C-S-g` (MRU non-current)
- Reads current session name.
- Lists all sessions with their `session_last_attached` timestamp.
- Sorts by newest first.
- Picks the first session that is not the current one.
- Switches to that session.

## Notes
- Both bindings are configured with `-n`, so they work **without tmux prefix**.
- If no previous session exists, `C-g` shows a small status message.
- If there is only one session, `C-S-g` is a no-op.

## Apply changes
After editing `tmux/.tmux.conf`, reload tmux config:

```tmux
prefix + r
```

(Your config already binds `r` under prefix to `source-file ~/.tmux.conf`.)

## Optional key alternatives
If `C-g` / `C-S-g` conflict with app shortcuts, alternatives:

- `M-g` and `M-G`
- `C-\\` and `C-|`
- prefix bindings instead of global (`bind-key` without `-n`)
