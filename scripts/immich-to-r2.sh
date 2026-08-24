#!/usr/bin/env bash
# Upload Immich photos (by album ID or explicit asset IDs) to Cloudflare R2
# and print the public CDN URL for each.
#
# When run with --album, uploads are namespaced under a key prefix derived
# from the album's title (e.g. album "Vancouver Trip" -> keys under
# "vancouver-trip/..."). --assets runs have no album context, so keys stay
# flat at the bucket root.
#
# Images are compressed with ImageOptim (imageoptim-cli driving ImageOptim.app)
# and stripped of GPS/location metadata with exiftool before upload. HEIC
# originals (common from iPhones) are re-encoded to jpg via sips first since
# ImageOptim.app can't touch HEIC directly. exiftool's GPS strip runs
# unconditionally on every asset, images and videos alike (QuickTime GPS
# atoms in mp4/mov are covered by -gps:all=/-location:all= too).
#
# Before compressing, images are auto-oriented (EXIF Orientation baked into
# pixel data via ImageMagick) since ImageOptim strips the Orientation tag
# without rotating the pixels, which would otherwise flip portrait photos
# sideways once the tag is gone.
#
# Requires: curl, jq, rclone (with an [r2] remote configured),
#           imageoptim-cli (`brew install imageoptim-cli`) + ImageOptim.app
#           (https://imageoptim.com/mac, must be in /Applications or symlinked
#           there), exiftool (`brew install exiftool`), imagemagick
#           (`brew install imagemagick`), sips (bundled with macOS)
#
# Config (env vars, put these in ~/.config/immich-to-r2.env and source it):
#   IMMICH_URL        e.g. http://192.168.1.50:2283
#   IMMICH_API_KEY    Immich API key (Account Settings > API Keys)
#   R2_REMOTE         rclone remote name, default: r2
#   R2_BUCKET         bucket name, e.g. photo-shares
#   PUBLIC_BASE_URL   e.g. https://photos.yourdomain.com
#   LOCAL_ARCHIVE_DIR optional, e.g. ~/Pictures/immich-r2-archive
#                     if set, a copy of every newly-uploaded asset (post
#                     compression/orientation-bake/GPS-strip, same bytes as
#                     what lands in R2) is saved here under its R2 key name.
#
# Usage:
#   immich-to-r2.sh --album <album_id>
#   immich-to-r2.sh --assets id1,id2,id3

set -euo pipefail

[ -f "${HOME}/.config/immich-to-r2.env" ] && source "${HOME}/.config/immich-to-r2.env"

: "${IMMICH_URL:?set IMMICH_URL}"
: "${IMMICH_API_KEY:?set IMMICH_API_KEY}"
R2_REMOTE="${R2_REMOTE:-r2}"
: "${R2_BUCKET:?set R2_BUCKET}"
: "${PUBLIC_BASE_URL:?set PUBLIC_BASE_URL}"
LOCAL_ARCHIVE_DIR="${LOCAL_ARCHIVE_DIR:-}"
[ -n "$LOCAL_ARCHIVE_DIR" ] && mkdir -p "$LOCAL_ARCHIVE_DIR"

usage() { echo "Usage: $0 --album <album_id> | --assets <id1,id2,...>"; exit 1; }
[ $# -ge 2 ] || usage

MODE="$1"; ARG="$2"
API_HDR=(-H "x-api-key: ${IMMICH_API_KEY}")

# Lowercase, non-alnum -> '-', collapse/trim dashes. e.g. "FUJIFILM X100V" -> "fujifilm-x100v"
slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]' '-' \
    | sed -e 's/-\{2,\}/-/g' -e 's/^-//' -e 's/-$//'
}

# In --album mode, namespace uploaded keys under a prefix slugged from the
# album title, e.g. "vancouver-trip/". Left empty for --assets (no album
# context to derive one from).
ALBUM_PREFIX=""
if [ "$MODE" = "--album" ]; then
  album_name="$(curl -sf "${API_HDR[@]}" "${IMMICH_URL}/api/albums/${ARG}" | jq -r '.albumName // ""')"
  [ -n "$album_name" ] && ALBUM_PREFIX="$(slug "$album_name")/"
fi

# "YYYY-MM-DD" -> "tue-jul-11". Tries GNU date (-d) then BSD date (-j -f) so
# this works both on macOS and a typical Linux box.
weekday_month_day() {
  local ymd="$1" out
  out="$(date -d "$ymd" +'%a-%b-%d' 2>/dev/null)" \
    || out="$(date -j -f '%Y-%m-%d' "$ymd" +'%a-%b-%d' 2>/dev/null)" || return 0
  tr '[:upper:]' '[:lower:]' <<< "$out"
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
rclone lsf --recursive "${R2_REMOTE}:${R2_BUCKET}" > "$existing_keys" 2>/dev/null || true

# Two phases so ImageOptim can run once over every downloaded image instead
# of once per file (imageoptim-cli happily takes many paths in one
# invocation and batches them internally). Phase 1 downloads/prepares every
# asset and records what it did in a TSV manifest (the download loop runs in
# a pipe subshell, so a file is used instead of an array to survive past
# it). Phase 2 runs the single batched ImageOptim call. Phase 3 uploads and
# prints URLs in the original asset order, using the manifest instead of
# redoing any work.
manifest="${tmpdir}/manifest.tsv"
: > "$manifest"

get_asset_ids | while read -r id; do
  [ -z "$id" ] && continue

  meta="$(curl -sf "${API_HDR[@]}" "${IMMICH_URL}/api/assets/${id}")"
  orig_name="$(jq -r '.originalFileName' <<< "$meta")"
  orig_ext="$(tr '[:upper:]' '[:lower:]' <<< "${orig_name##*.}")"
  asset_type="$(jq -r '.type // ""' <<< "$meta")"

  # ImageOptim can't touch HEIC, so re-encode to jpg first and upload/key
  # under .jpg instead of .heic.
  ext="$orig_ext"
  if [ "$asset_type" = "IMAGE" ] && { [ "$orig_ext" = "heic" ] || [ "$orig_ext" = "heif" ]; }; then
    ext="jpg"
  fi

  # Build <dow>-<mon>-<day>-<make>-<location>-<shortid>.<ext>, e.g.
  # "sat-jul-11-fujifilm-vancouver-b6f3b186.jpg". Any missing field (no EXIF
  # camera, no GPS/reverse-geocoded city) is just omitted, not left blank.
  make="$(jq -r '.exifInfo.make // ""' <<< "$meta")"
  loc="$(jq -r '.exifInfo.city // .exifInfo.country // ""' <<< "$meta")"
  dt="$(jq -r '.exifInfo.dateTimeOriginal // .fileCreatedAt // ""' <<< "$meta")"
  date_part="$(weekday_month_day "$(cut -c1-10 <<< "$dt")")"
  short_id="${id:0:8}"

  parts=()
  [ -n "$date_part" ] && parts+=("$date_part")
  [ -n "$make" ] && parts+=("$(slug "$make")")
  [ -n "$loc" ] && parts+=("$(slug "$loc")")
  parts+=("$short_id")

  name="$(IFS=-; echo "${parts[*]}")"
  key="${ALBUM_PREFIX}${name}.${ext}"

  if grep -qxF "$key" "$existing_keys"; then
    printf '%s\t%s\texisting\t%s\n' "$key" "" "" >> "$manifest"
    continue
  fi

  # Flat filename in tmpdir regardless of album prefix, so we don't need to
  # mkdir -p subdirs just for scratch work.
  local_path="${tmpdir}/${short_id}.${ext}"

  if [ "$asset_type" = "IMAGE" ] && { [ "$orig_ext" = "heic" ] || [ "$orig_ext" = "heif" ]; }; then
    src_path="${tmpdir}/${short_id}.${orig_ext}"
    curl -sf "${API_HDR[@]}" "${IMMICH_URL}/api/assets/${id}/original" -o "$src_path"
    sips -s format jpeg "$src_path" --out "$local_path" >/dev/null 2>&1
    rm -f "$src_path"
  else
    curl -sf "${API_HDR[@]}" "${IMMICH_URL}/api/assets/${id}/original" -o "$local_path"
  fi

  if [ "$asset_type" = "IMAGE" ]; then
    # Bake the EXIF Orientation into the pixels first: ImageOptim strips the
    # Orientation tag without rotating the image data, which would otherwise
    # turn portrait photos sideways once the tag is gone.
    magick "$local_path" -auto-orient "$local_path" >/dev/null 2>&1 || true
  fi
  # Strip GPS/location metadata from both images and videos. Runs before the
  # batched ImageOptim pass below (order doesn't matter functionally; this
  # just keeps it here alongside the rest of the per-file prep work).
  exiftool -q -overwrite_original -gps:all= -location:all= -xmp:geotag= "$local_path" >/dev/null 2>&1 || true

  printf '%s\t%s\tnew\t%s\n' "$key" "$local_path" "$asset_type" >> "$manifest"
done

# Phase 2: lossy-compress every newly downloaded image in one ImageOptim
# invocation instead of one process launch per file (no-op/non-fatal for any
# format ImageOptim doesn't support).
image_paths=()
while IFS=$'\t' read -r m_key m_path m_status m_type; do
  [ "$m_status" = "new" ] && [ "$m_type" = "IMAGE" ] && image_paths+=("$m_path")
done < "$manifest"
if [ "${#image_paths[@]}" -gt 0 ]; then
  imageoptim "${image_paths[@]}" >/dev/null 2>&1 || true
fi

# Phase 3: upload and print, in the same order assets were requested.
while IFS=$'\t' read -r key local_path status asset_type; do
  [ -z "$key" ] && continue

  if [ "$status" = "existing" ]; then
    echo "${PUBLIC_BASE_URL}/${key}"
    continue
  fi

  rclone copyto "$local_path" "${R2_REMOTE}:${R2_BUCKET}/${key}" \
    --header-upload "Cache-Control: public, max-age=31536000, immutable" \
    --quiet

  if [ -n "$LOCAL_ARCHIVE_DIR" ]; then
    mkdir -p "$(dirname "${LOCAL_ARCHIVE_DIR}/${key}")"
    cp "$local_path" "${LOCAL_ARCHIVE_DIR}/${key}"
  fi

  rm -f "$local_path"
  echo "${PUBLIC_BASE_URL}/${key}"
done < "$manifest"
