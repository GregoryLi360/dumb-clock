#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/dumb-clock-tests.XXXXXX")
trap 'rm -rf "$TEST_TMP"' EXIT HUP INT TERM
xcrun swiftc -swift-version 6 Stopwatch.swift TimingTests.swift -o "$TEST_TMP/timing-tests"
"$TEST_TMP/timing-tests"
xcrun swiftc -swift-version 6 -framework AppKit Stopwatch.swift DurationInput.swift PickerTests.swift \
    -o "$TEST_TMP/picker-tests"
"$TEST_TMP/picker-tests"
