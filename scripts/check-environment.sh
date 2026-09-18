#!/bin/bash
set -euo pipefail
for tool in swiftc; do
  if ! xcrun --find "$tool" >/dev/null 2>&1; then
    echo "Missing Command Line Tools component: $tool" >&2
    exit 1
  fi
done
xcrun --show-sdk-path >/dev/null
for tool in python3 codesign security; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing build tool: $tool" >&2
    exit 1
  fi
done
