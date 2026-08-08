#!/usr/bin/env bash
# Fetches the live model list from the tailscale AI proxy and diffs it
# against what's configured in models.json, per provider/baseUrl.
#
# Usage: ./diff-models.sh
#
# Prints:
#   NEW <baseUrl> <model-id> <owned_by/provider.id>   -- present on proxy, not in models.json
#   GONE <provider-key> <model-id>                    -- in models.json, no longer on proxy
#
# Exit 0 always; this is informational, not pass/fail.

set -uo pipefail

MODELS_JSON="${MODELS_JSON:-$HOME/.pi/agent/models.json}"

if [[ ! -f "$MODELS_JSON" ]]; then
  echo "models.json not found at $MODELS_JSON" >&2
  exit 1
fi

# Collect distinct base URLs (strip trailing /v1 to hit /v1/models consistently)
mapfile -t BASE_URLS < <(jq -r '.providers[].baseUrl' "$MODELS_JSON" | sed 's#/v1$##' | sort -u)

for base in "${BASE_URLS[@]}"; do
  echo "# Fetching $base/v1/models" >&2
  resp=$(curl -s "$base/v1/models")
  if [[ -z "$resp" ]] || ! echo "$resp" | jq -e . >/dev/null 2>&1; then
    echo "# WARNING: could not fetch/parse $base/v1/models" >&2
    continue
  fi

  # All model ids + backing provider (anthropic/openai/gemini/etc) currently on the proxy
  mapfile -t LIVE < <(echo "$resp" | jq -r '.data[] | "\(.id)\t\(.metadata.provider.id // "unknown")"')

  # All model ids currently configured under providers whose baseUrl matches this base
  mapfile -t CONFIGURED < <(jq -r --arg base "$base" \
    '.providers | to_entries[] | select((.value.baseUrl | sub("/v1$";"")) == $base) | .value.models[]?.id' \
    "$MODELS_JSON")

  for entry in "${LIVE[@]}"; do
    id="${entry%%$'\t'*}"
    backing="${entry##*$'\t'}"
    if ! printf '%s\n' "${CONFIGURED[@]}" | grep -qx "$id"; then
      echo "NEW	$base	$id	$backing"
    fi
  done

  for id in "${CONFIGURED[@]}"; do
    if ! printf '%s\n' "${LIVE[@]}" | cut -f1 | grep -qx "$id"; then
      echo "GONE	$base	$id"
    fi
  done
done
