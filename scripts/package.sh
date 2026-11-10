#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
VERSION=${VERSION:-1.0.0}
export VERSION
sh build.sh

PACKAGE_TMP=$(mktemp -d "${TMPDIR:-/tmp}/dumb-clock-package.XXXXXX")
trap 'rm -rf "$PACKAGE_TMP"' EXIT HUP INT TERM
mkdir -p dist
if command -v uvx >/dev/null 2>&1; then
    uvx --from 'dmgbuild==1.6.7' dmgbuild -s scripts/dmg-settings.py -D "root=$PWD" \
        'stopwatch' "$PACKAGE_TMP/stopwatch-$VERSION.dmg"
else
    python3 -c 'from importlib.metadata import version; assert version("dmgbuild") == "1.6.7", "Install dmgbuild==1.6.7"'
    python3 -m dmgbuild -s scripts/dmg-settings.py -D "root=$PWD" \
        'stopwatch' "$PACKAGE_TMP/stopwatch-$VERSION.dmg"
fi
hdiutil verify "$PACKAGE_TMP/stopwatch-$VERSION.dmg"
mv "$PACKAGE_TMP/stopwatch-$VERSION.dmg" "dist/stopwatch-$VERSION.dmg"
(
    cd dist
    shasum -a 256 "stopwatch-$VERSION.dmg" > "stopwatch-$VERSION.dmg.sha256"
)
printf '%s\n' "$PWD/dist/stopwatch-$VERSION.dmg"
