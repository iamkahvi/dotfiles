#!/bin/sh
# Pane process for the kahvi.new-pi-tab plugin.
# Starts pi directly (no interactive shell startup first). When pi exits,
# replaces itself with an interactive shell so the tab stays usable.
#
# Env (set by the picker with `herdr plugin pane open --env`):
#   NEW_PI_MODEL  value for `pi --model`; empty means the settings default
#   NEW_PI_ARGS   extra pi arguments, split on spaces (for tests)

# Do not leak picker variables into pi or the shell.
model=${NEW_PI_MODEL:-}
extra=${NEW_PI_ARGS:-}
unset NEW_PI_MODEL NEW_PI_ARGS

set --
[ -n "$model" ] && set -- --model "$model"
# shellcheck disable=SC2086 # NEW_PI_ARGS is split on purpose
[ -n "$extra" ] && set -- "$@" $extra

if [ -x /opt/dev/bin/devx ]; then
	SHOPIFY_AI_RTK=false /opt/dev/bin/devx pi "$@"
else
	pi "$@"
fi

exec "${SHELL:-/bin/zsh}" -i
