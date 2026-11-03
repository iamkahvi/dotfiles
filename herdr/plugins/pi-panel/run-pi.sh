#!/bin/bash
# Portable pi launcher for the herdr pane.
# Machine A: pi installed via bun at ~/.bun/bin/pi
# Machine B: pi via pnpm shim or Shopify devx (`devx pi`)

LOG="${HERDR_PLUGIN_STATE_DIR:-${TMPDIR:-/tmp}}/run-pi.log"
{
  echo "=== $(date) cwd=$PWD"
  echo "PATH=$PATH"
  echo "TERM=$TERM"
} >>"$LOG" 2>&1

launch() {
  echo "[run-pi] launching: $*" >>"$LOG"
  "$@" 2> >(tee -a "$LOG" >&2)
  rc=$?
  echo "[run-pi] '$*' exited rc=$rc" >>"$LOG"
  if [ "$rc" -ne 0 ]; then
    echo ""
    echo "run-pi.sh: '$*' exited with $rc — log: $LOG"
    echo "pane stays open 60s for reading"
    sleep 60
  fi
  exit "$rc"
}

if [ -x "$HOME/.bun/bin/pi" ]; then
  launch "$HOME/.bun/bin/pi" "$@"
fi

if [ -x /opt/dev/bin/devx ]; then
  export SHOPIFY_AI_RTK=false
  launch /opt/dev/bin/devx pi "$@"
fi

# Last resort: whatever pi is on PATH
if command -v pi >/dev/null 2>&1; then
  launch pi "$@"
fi

echo "run-pi.sh: could not find pi (tried ~/.bun/bin/pi, PATH, devx)" | tee -a "$LOG" >&2
sleep 60
exit 127
