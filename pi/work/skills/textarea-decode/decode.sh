#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: decode.sh <textarea_url_or_hash>" >&2
  exit 1
fi

input="$1"

# Extract hash fragment if full URL provided
if [[ "$input" == *"#"* ]]; then
  hash="${input##*#}"
else
  hash="$input"
fi

ruby -e '
require "base64"
require "zlib"

fragment = ARGV[0]
padding = (4 - fragment.length % 4) % 4
fragment += "=" * padding

data = Base64.urlsafe_decode64(fragment)
inflate = Zlib::Inflate.new(-Zlib::MAX_WBITS)
puts inflate.inflate(data)
inflate.close
' "$hash"
