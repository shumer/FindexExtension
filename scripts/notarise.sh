#!/bin/bash
# Notarize a signed app with an existing Keychain profile and staple its ticket.
set -euo pipefail
if [ "$#" != 2 ]; then
  echo 'Usage: scripts/notarise.sh <app-path> <keychain-profile>' >&2
  exit 2
fi
app_path="$1"
profile="$2"
credentials=(--keychain-profile "$profile")
if [ -n "${FINDERPACK_NOTARY_KEYCHAIN:-}" ]; then credentials+=(--keychain "$FINDERPACK_NOTARY_KEYCHAIN"); fi
if [ ! -d "$app_path/Contents" ]; then echo 'Expected an application bundle.' >&2; exit 2; fi
codesign --verify --deep --strict "$app_path"
mkdir -p build/notary
work="$(mktemp -d "$PWD/build/notary/submission.XXXXXX")"
ditto -c -k --keepParent "$app_path" "$work/FinderPack.zip"
xcrun notarytool submit "$work/FinderPack.zip" "${credentials[@]}" \
  --wait --output-format json > "$work/result.json" || true
cat "$work/result.json"
status="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status", ""))' "$work/result.json")"
identifier="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("id", ""))' "$work/result.json")"
if [ "$status" != Accepted ]; then
  if [ -n "$identifier" ]; then
    xcrun notarytool log "$identifier" "${credentials[@]}" "$work/notary-log.json" || true
  fi
  echo "Notarization not accepted. See $work" >&2
  exit 1
fi
xcrun stapler staple "$app_path"
xcrun stapler validate "$app_path"
spctl --assess --type execute --verbose=2 "$app_path"
echo "Notarization evidence: $work"
