#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="$(cat VERSION)"
build_number="$(git rev-list --count HEAD)"
: "${CODESIGN_IDENTITY:?Set the release signing identity}"
git diff --quiet HEAD || { echo 'Commit tracked changes before packaging a release.' >&2; exit 1; }
python3 - "$version" "$build_number" <<'PY'
import plistlib
import subprocess
import sys
from pathlib import Path
info = plistlib.loads(Path('build/FinderPack.app/Contents/Info.plist').read_bytes())
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
if (info.get('CFBundleShortVersionString'), info.get('CFBundleVersion'), info.get('FinderPackSourceCommit')) != (sys.argv[1], sys.argv[2], commit):
    raise SystemExit('The application does not match this commit/version/build. Rebuild and notarize it first.')
PY
archive="build/FinderPack-${version}-${build_number}.zip"
image="build/FinderPack-${version}-${build_number}.dmg"
if [ -e "$archive" ] || [ -e "$image" ]; then
  echo "Release artifacts already exist; refusing to replace them." >&2
  exit 1
fi
xcrun stapler validate build/FinderPack.app
spctl --assess --type execute build/FinderPack.app
stage="$(mktemp -d "$PWD/build/dmg.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
ditto build/FinderPack.app "$stage/FinderPack.app"
ln -s /Applications "$stage/Applications"
ditto -c -k --sequesterRsrc --keepParent build/FinderPack.app "$archive"
hdiutil create -volname FinderPack -srcfolder "$stage" -ov -format UDZO "$image"
codesign --force --timestamp --sign "${CODESIGN_IDENTITY:?Set the release signing identity}" "$image"
notary_arguments=(--keychain-profile "${FINDERPACK_NOTARY_PROFILE:-FinderPack}")
if [ -n "${FINDERPACK_NOTARY_KEYCHAIN:-}" ]; then notary_arguments+=(--keychain "$FINDERPACK_NOTARY_KEYCHAIN"); fi
xcrun notarytool submit "$image" "${notary_arguments[@]}" --wait --output-format json > build/dmg-notary.json
python3 -c 'import json; assert json.load(open("build/dmg-notary.json"))["status"] == "Accepted"'
xcrun stapler staple "$image"
xcrun stapler validate "$image"
spctl --assess --type open --context context:primary-signature "$image"
shasum -a 256 "$archive" "$image" > build/SHA256SUMS
python3 - "$version" "$build_number" <<'PY'
import json
import subprocess
import sys
from pathlib import Path
metadata = {'version': sys.argv[1], 'build': int(sys.argv[2]),
            'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
            'swift': subprocess.check_output(['swift', '--version'], text=True).strip(),
            'sdk': subprocess.check_output(['xcrun', '--show-sdk-version'], text=True).strip(),
            'architectures': subprocess.check_output(['lipo', '-archs', 'build/FinderPack.app/Contents/MacOS/FinderPack'], text=True).split()}
Path('build/build-info.json').write_text(json.dumps(metadata, indent=2) + '\n')
PY
