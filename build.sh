#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
skip_tests=0
release=0
for argument in "$@"; do
  case "$argument" in
    --skip-tests) skip_tests=1 ;;
    --no-install) ;;
    --release) release=1 ;;
    *) echo "Unknown option: $argument" >&2; exit 2 ;;
  esac
done
./scripts/check-environment.sh
if [ "$skip_tests" = 0 ]; then ./run-tests.sh; fi
./scripts/check-source.sh
if [ "$release" = 1 ]; then
  python3 scripts/build-app.py --release
else
  python3 scripts/build-app.py
fi
python3 scripts/verify-bundle.py build/FinderPack.app
