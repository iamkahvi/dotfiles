# Pi Panel

Toggle a pi coding-agent session in a side panel of the current Herdr tab.

Bound to `prefix+p` via `[[keys.command]]` in `herdr/config.toml`, invoking the
`kahvi.pi-panel.toggle` action:

- No pi panel in the tab: splits the focused pane (right if it is at least 100
  columns wide, down otherwise) and starts `pi` in the focused pane's working
  directory. The panel takes focus.
- Panel open but unfocused: focuses it. Pi keeps running in the background and
  Herdr tracks its agent state.
- Panel focused and pi is working: left alone (never killed mid-task).
- Panel focused and pi idle: closes the panel.

## Install

    herdr plugin link ~/dotfiles/herdr/plugins/pi-panel
    herdr server reload-config

## Test

    python3 -m unittest discover -s ~/dotfiles/herdr/plugins/pi-panel -p 'test_*.py'
