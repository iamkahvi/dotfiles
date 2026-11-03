#!/usr/bin/env bash
# Smoke-tests every model in models.json by actually running it through pi
# with a tool call, since that's the exact combination (text + reasoning +
# function tools) that has broken models like gpt-5.6-luna in the past.
#
# Usage:
#   ./check-models.sh              # test all models
#   ./check-models.sh gpt-5.6-luna # test models matching substring
#
# Exit code is nonzero if any model fails.

set -uo pipefail

MODELS_JSON="${MODELS_JSON:-$HOME/.pi/agent/models.json}"
FILTER="${1:-}"
TIMEOUT="${TIMEOUT:-60}"

if [[ ! -f "$MODELS_JSON" ]]; then
  echo "models.json not found at $MODELS_JSON" >&2
  exit 1
fi

TARGETS=()
while IFS= read -r line; do TARGETS+=("$line"); done < <(jq -r '.providers | to_entries[] | .key as $p | .value.models[].id as $m | "\($p)/\($m)"' "$MODELS_JSON")

if [[ -n "$FILTER" ]]; then
  FILTERED=()
  while IFS= read -r line; do FILTERED+=("$line"); done < <(printf '%s\n' "${TARGETS[@]}" | grep -i "$FILTER")
  TARGETS=("${FILTERED[@]}")
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "No models matched filter '$FILTER'" >&2
  exit 1
fi

FAILED=()
PASSED=()

for model in "${TARGETS[@]}"; do
  echo "==> Testing $model"
  out=$(timeout "$TIMEOUT" pi -p --model "$model" --no-session -t bash \
    "Run the bash tool to echo 'smoketest-ok', then reply with just that word." 2>&1)
  status=$?

  if [[ $status -ne 0 ]]; then
    echo "    FAIL (exit $status)"
    echo "$out" | sed 's/^/    | /'
    FAILED+=("$model")
    continue
  fi

  if ! echo "$out" | grep -qi "smoketest-ok"; then
    echo "    FAIL (unexpected output)"
    echo "$out" | sed 's/^/    | /'
    FAILED+=("$model")
    continue
  fi

  echo "    OK"
  PASSED+=("$model")
done

echo
echo "===== Summary ====="
echo "Passed: ${#PASSED[@]}/${#TARGETS[@]}"
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "Failed:"
  printf '  - %s\n' "${FAILED[@]}"
  exit 1
fi

exit 0
