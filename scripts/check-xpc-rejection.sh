#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/integration
identity="$(security find-identity -v -p codesigning | awk '/Developer ID Application/ {print $2; exit}')"
if [ -z "$identity" ]; then echo 'Developer ID is required.' >&2; exit 1; fi
xcrun swiftc -parse-as-library -swift-version 6 -strict-concurrency=complete -warnings-as-errors \
  -module-cache-path "$PWD/.build/module-cache" Shared/DiagnosticProtocol.swift \
  Tests/Integration/RejectedClient.swift -o .build/integration/RejectedClient
codesign --force --sign "$identity" --options runtime --timestamp \
  --identifier com.shumer.finderpack.untrusted-test .build/integration/RejectedClient
service="$(/usr/libexec/PlistBuddy -c 'Print FinderPackService' /Applications/FinderPack.app/Contents/Info.plist)"
.build/integration/RejectedClient "$service"
