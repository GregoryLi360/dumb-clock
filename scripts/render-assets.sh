#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift scripts/render-assets.swift
ASSET_TMP=$(mktemp -d "${TMPDIR:-/tmp}/dumb-clock-icons.XXXXXX")
trap 'rm -rf "$ASSET_TMP"' EXIT HUP INT TERM
ICONSET="$ASSET_TMP/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" assets/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    doubled=$((size * 2))
    sips -z "$doubled" "$doubled" assets/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o assets/AppIcon.icns
