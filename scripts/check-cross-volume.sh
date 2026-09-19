#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
stage="$(mktemp -d "$PWD/.build/volume-test.XXXXXX")"
cleanup() {
  if hdiutil detach "$stage/mount" >/dev/null 2>&1; then
    rm -rf "$stage"
  else
    echo "Test image retained at $stage because detaching did not succeed." >&2
  fi
}
trap cleanup EXIT
mkdir "$stage/mount"
hdiutil create -size 64m -fs APFS -volname FinderPackTests "$stage/test.dmg" >/dev/null
hdiutil attach "$stage/test.dmg" -mountpoint "$stage/mount" -nobrowse -owners on >/dev/null
FINDERPACK_TEST_VOLUME="$stage/mount" ./run-tests.sh
