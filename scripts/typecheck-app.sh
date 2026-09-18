#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./run-tests.sh
for target in App Agent Extension; do
  flags=(-module-name "FinderPack${target}")
  if [ "$target" = Extension ]; then flags=(-application-extension); fi
  xcrun swiftc -typecheck -parse-as-library -swift-version 6 \
    -strict-concurrency=complete -warnings-as-errors -target "$(uname -m)-apple-macos14.0" \
    -module-cache-path "$PWD/.build/module-cache" -I .build/core-checks \
    "${flags[@]}" Shared/*.swift "$target"/*.swift
 done
