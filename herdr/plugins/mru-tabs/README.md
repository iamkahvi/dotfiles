# MRU Tabs

Keeps tabs named exactly `TODO` at the far left of each workspace. Multiple TODO
tabs stay together in their existing relative order. Creating, renaming, or moving
a tab restores this pinned prefix, including after a manual drag. Renaming a TODO
tab to anything else removes its pin. Repairs run asynchronously through event
hooks, not a native drag restriction.

When any agent transitions into `working`, its tab moves immediately after the
TODO tabs (or leftmost if there are none), matching the trigger used by MRU Spaces.
Focusing a tab, running shell commands, or sending input to an already-working
agent does not promote it. Other unpinned tabs keep their relative order, and
focus stays unchanged.

This changes Herdr's persisted tab order, not just its display. Workspace order
is untouched by this plugin; MRU Spaces can run alongside it.

Concurrent hooks are serialized per workspace and session. Duplicate, superseded,
and older transitions cannot displace a newer processed transition in the same
workspace. State is stored under `HERDR_PLUGIN_STATE_DIR`; a recreated server
socket resets that session's sequence tracking.

Requires Herdr 0.9.0+ and Python 3.10+ on macOS or Linux. Uses the socket-only
`tab.move` method, resolving the event's pane to its current tab from
`session.snapshot` rather than relying on the focused tab.

## Link locally

```sh
herdr plugin link ~/dotfiles/herdr/plugins/mru-tabs
```

Disable without removing the plugin:

```sh
herdr plugin disable kahvi.mru-tabs
```

## Test

```sh
python3 -m unittest discover -s ~/dotfiles/herdr/plugins/mru-tabs -p 'test_*.py'
```

Tests use a temporary Unix socket and plugin state, not your live Herdr session.
