#!/usr/bin/env bash
# Upload Immich photos (by album ID or explicit asset IDs) to Cloudflare R2
# and print the public CDN URL for each.
#
# Requires: curl, jq, rclone (with an [r2] remote configured)
#
# Config (env vars, put these in ~/.config/immich-to-r2.env and source it):
#   IMMICH_URL        e.g. http://192.168.1.50:2283
#   IMMICH_API_KEY    Immich API key (Account Settings > API Keys)
#   R2_REMOTE         rclone remote name, default: r2
#   R2_BUCKET         bucket name, e.g. photo-shares
#   PUBLIC_BASE_URL   e.g. https://photos.yourdomain.com
#
# Usage:
#   immich-to-r2.sh --album <album_id>
#   immich-to-r2.sh --assets id1,id2,id3

set -euo pipefail

: "${IMMICH_URL:?set IMMICH_URL}"
: "${IMMICH_API_KEY:?set IMMICH_API_KEY}"
R2_REMOTE="${R2_REMOTE:-r2}"
: "${R2_BUCKET:?set R2_BUCKET}"
: "${PUBLIC_BASE_URL:?set PUBLIC_BASE_URL}"

usage() { echo "Usage: $0 --album <album_id> | --assets <id1,id2,...>"; exit 1; }
[ $# -ge 2 ] || usage

MODE="$1"; ARG="$2"
API_HDR=(-H "x-api-key: ${IMMICH_API_KEY}")

# Lowercase, non-alnum -> '-', collapse/trim dashes. e.g. "FUJIFILM X100V" -> "fujifilm-x100v"
slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]' '-' \
    | sed -e 's/-\{2,\}/-/g' -e 's/^-//' -e 's/-$//'
}

get_asset_ids() {
  case "$MODE" in
    --album)
      # Immich no longer embeds assets in GET /api/albums/{id}; use search/metadata
      # with pagination since results are capped per page.
      page=1
      while :; do
        resp="$(curl -sf "${API_HDR[@]}" -H 'Content-Type: application/json' \
          -d "{\"albumIds\":[\"${ARG}\"],\"page\":${page}}" \
          "${IMMICH_URL}/api/search/metadata")"
        jq -r '.assets.items[].id' <<< "$resp"
        next="$(jq -r '.assets.nextPage' <<< "$resp")"
        [ "$next" = "null" ] && break
        page="$next"
      done
      ;;
    --assets)
      tr ',' '\n' <<< "$ARG"
      ;;
    *) usage ;;
  esac
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Snapshot existing bucket contents once so re-runs can skip unchanged assets
# instead of re-downloading originals from Immich and re-uploading to R2.
existing_keys="${tmpdir}/existing_keys.txt"
rclone lsf "${R2_REMOTE}:${R2_BUCKET}" > "$existing_keys" 2>/dev/null || true

get_asset_ids | while read -r id; do
  [ -z "$id" ] && continue

  meta="$(curl -sf "${API_HDR[@]}" "${IMMICH_URL}/api/assets/${id}")"
  orig_name="$(jq -r '.originalFileName' <<< "$meta")"
  ext="$(tr '[:upper:]' '[:lower:]' <<< "${orig_name##*.}")"

  # Build <make>-<model>-<location>-<date>-<shortid>.<ext>. Any missing field
  # (no EXIF camera, no GPS/reverse-geocoded city) is just omitted, not left blank.
  make="$(jq -r '.exifInfo.make // ""' <<< "$meta")"
  model="$(jq -r '.exifInfo.model // ""' <<< "$meta")"
  loc="$(jq -r '.exifInfo.city // .exifInfo.country // ""' <<< "$meta")"
  dt="$(jq -r '.exifInfo.dateTimeOriginal // .fileCreatedAt // ""' <<< "$meta")"
  date_part="$(cut -c1-10 <<< "$dt" | tr -d '-')"
  short_id="${id:0:8}"

  parts=()
  [ -n "$make" ] && parts+=("$(slug "$make")")
  [ -n "$model" ] && parts+=("$(slug "$model")")
  [ -n "$loc" ] && parts+=("$(slug "$loc")")
  [ -n "$date_part" ] && parts+=("$date_part")
  parts+=("$short_id")

  name="$(IFS=-; echo "${parts[*]}")"
  key="${name}.${ext}"

  if grep -qxF "$key" "$existing_keys"; then
    echo "${PUBLIC_BASE_URL}/${key}"
    continue
  fi

  local_path="${tmpdir}/${key}"
  curl -sf "${API_HDR[@]}" "${IMMICH_URL}/api/assets/${id}/original" -o "$local_path"

  rclone copyto "$local_path" "${R2_REMOTE}:${R2_BUCKET}/${key}" \
    --header-upload "Cache-Control: public, max-age=31536000, immutable" \
    --quiet

  rm -f "$local_path"
  echo "${PUBLIC_BASE_URL}/${key}"
done
