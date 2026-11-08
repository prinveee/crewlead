#!/usr/bin/env bash
# Render docs/brand/social-preview.svg to social-preview.png (1280x640).
# Uses rsvg-convert when present, else headless Google Chrome.
set -euo pipefail
cd "$(dirname "$0")"
svg=social-preview.svg
png=social-preview.png

if command -v rsvg-convert >/dev/null 2>&1; then
  rsvg-convert -w 1280 -h 640 "$svg" -o "$png"
else
  chrome="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  {
    echo '<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;padding:0;background:#0d1117}svg{display:block}</style></head><body>'
    cat "$svg"
    echo '</body></html>'
  } > "$tmp/page.html"
  "$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --window-size=1280,640 --screenshot="$PWD/$png" "file://$tmp/page.html" >/dev/null 2>&1
fi
ls -l "$png"
