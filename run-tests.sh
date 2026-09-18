#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build/core-checks .build/module-cache
xcrun swiftc -swift-version 6 -strict-concurrency=complete -warnings-as-errors -target "$(uname -m)-apple-macos14.0" \
  -module-cache-path "$PWD/.build/module-cache" -parse-as-library \
  -emit-library -emit-module -module-name FinderPackCore \
  -emit-module-path .build/core-checks/FinderPackCore.swiftmodule \
  Sources/FinderPackCore/*.swift -o .build/core-checks/libFinderPackCore.dylib
xcrun swiftc -swift-version 6 -strict-concurrency=complete -warnings-as-errors -target "$(uname -m)-apple-macos14.0" \
  -module-cache-path "$PWD/.build/module-cache" \
  -I .build/core-checks -L .build/core-checks -lFinderPackCore \
  -Xlinker -rpath -Xlinker "$PWD/.build/core-checks" \
  Tests/CoreChecks/main.swift -o .build/core-checks/CoreChecks
.build/core-checks/CoreChecks
