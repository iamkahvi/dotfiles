#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: search_sessions.sh [options]

Interactive session search with fzf.
Select a match and emit a pi command for that session.

Options:
  -u, --user-only      Only include lines from user messages ("role":"user")
  -q, --query <text>   Initial fzf query
  -p, --path <dir>     Directory to search for session jsonl files (default: .)
      --dry-run        Print selected session file path only
      --run            Run pi immediately instead of printing command
  -h, --help           Show this help

Examples:
  ./search_sessions.sh
  ./search_sessions.sh -u
  ./search_sessions.sh -q checkout
  ./search_sessions.sh -p ~/.pi/agent-shopify/sessions
  ./search_sessions.sh -u -q graphql -p ~/.pi/agent-shopify/sessions
EOF
}

user_only=0
initial_query=""
search_path="."
dry_run=0
run_now=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--user-only)
      user_only=1
      shift
      ;;
    -q|--query)
      initial_query="${2:-}"
      shift 2
      ;;
    -p|--path)
      if [[ -z "${2:-}" ]]; then
        echo "Missing value for $1" >&2
        exit 1
      fi
      search_path="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --run)
      run_now=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

for cmd in rg fzf python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

if [[ $run_now -eq 1 ]] && ! command -v pi >/dev/null 2>&1; then
  echo "Missing required command: pi" >&2
  exit 1
fi

if [[ ! -d "$search_path" ]]; then
  echo "Search path is not a directory: $search_path" >&2
  exit 1
fi

base_cmd=(
  rg
  --line-number
  --with-filename
  --no-heading
  --glob '**/*.jsonl'
  --glob '!.DS_Store'
  -- '.' "$search_path"
)

if [[ $user_only -eq 1 ]]; then
  candidates="$("${base_cmd[@]}" 2>/dev/null | rg --fixed-strings '"role":"user"' || true)"
else
  candidates="$("${base_cmd[@]}" 2>/dev/null || true)"
fi

if [[ -z "$candidates" ]]; then
  echo "No session lines found." >&2
  exit 1
fi

selected_line="$(
  printf '%s\n' "$candidates" | fzf \
    --query "$initial_query" \
    --prompt 'sessions> ' \
    --header 'Type to filter. Enter selects session' \
    --delimiter ':' \
    --preview 'file={1}; first=$(rg -m1 --no-line-number --fixed-strings "\"role\":\"user\"" "$file" || true); if [[ -z "$first" ]]; then echo "[no user prompt found]"; exit 0; fi; printf "%s\n" "$first" | sed -E "s/.*\"text\":\"(([^\"\\\\]|\\\\.)*)\".*/\1/" | python3 -c "import sys; s=sys.stdin.read(); print(bytes(s, \"utf-8\").decode(\"unicode_escape\"), end=\"\")"' \
    --preview-window 'up,3,wrap'
)"

[[ -n "$selected_line" ]] || exit 0

session_file="${selected_line%%:*}"

if [[ $dry_run -eq 1 ]]; then
  printf '%s\n' "$session_file"
  exit 0
fi

printf -v pi_cmd 'pi --session %q' "$session_file"

if [[ $run_now -eq 1 ]]; then
  exec pi --session "$session_file"
fi

printf '%s\n' "$pi_cmd"
