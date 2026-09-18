#!/usr/bin/env python3
"""Verify the assembled artifact, not only its input templates."""
import plistlib
import re
import subprocess
import sys
from pathlib import Path

app = Path(sys.argv[1]).resolve()
app_info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
for relative in ['.', 'Contents/Library/Helpers/FinderPackAgent.app', 'Contents/PlugIns/FinderPackExtension.appex']:
    bundle = app / relative
    info = plistlib.loads((bundle / 'Contents/Info.plist').read_bytes())
    assert info['CFBundleVersion'] == app_info['CFBundleVersion'], 'Inconsistent build number'
    assert info['CFBundleShortVersionString'] == app_info['CFBundleShortVersionString'], 'Inconsistent version'
    assert '$(' not in repr(info), 'Unresolved build setting'
    binary = bundle / 'Contents/MacOS' / info['CFBundleExecutable']
    assert binary.is_file(), 'Missing executable'
    dependencies = subprocess.check_output(['otool', '-L', str(binary)], text=True)
    assert '.build/' not in dependencies and 'libFinderPackCore.dylib' not in dependencies, 'Development-only library dependency'
    load_commands = subprocess.check_output(['otool', '-l', str(binary)], text=True)
    assert 'LC_MAIN' in load_commands, 'Expected Mach-O executable entry point'
    assert re.search(r'minos\s+14\.0', load_commands), 'Incorrect deployment target'
    subprocess.run(['codesign', '--verify', '--strict', str(bundle)], check=True)
    signature = subprocess.run(['codesign', '-dv', '--verbose=4', str(bundle)], capture_output=True, text=True, check=True).stderr
    assert 'runtime' in signature, 'Hardened runtime is missing'
    exported = subprocess.run(['codesign', '-d', '--entitlements', '-', '--xml', str(bundle)], capture_output=True, check=True)
    assert exported.stdout, 'Cannot read entitlements; signature inspection may require leaving a restricted sandbox'
    entitlements = plistlib.loads(exported.stdout)
    assert entitlements.get('com.apple.security.application-groups') == [app_info['FinderPackGroup']], 'App Group mismatch'
    if bundle.suffix == '.appex':
        assert entitlements.get('com.apple.security.app-sandbox') is True, 'Extension is not sandboxed'
        assert entitlements.get('com.apple.security.temporary-exception.mach-lookup.global-name') == [app_info['FinderPackService']], 'Mach lookup mismatch'
    else:
        assert not entitlements.get('com.apple.security.app-sandbox', False), 'Unexpected app/agent sandbox'
    if app_info['FinderPackBuildKind'] == 'developer-id':
        assert 'Authority=Developer ID Application:' in signature, 'Developer ID authority unavailable'
        assert 'Timestamp=' in signature, 'Secure timestamp is missing'
        assert f"TeamIdentifier={app_info['FinderPackTeam']}" in signature, 'Wrong signing team'

extension = app / 'Contents/PlugIns/FinderPackExtension.appex'
info = plistlib.loads((extension / 'Contents/Info.plist').read_bytes())
assert info['NSExtension']['NSExtensionPointIdentifier'] == 'com.apple.FinderSync'
assert info['NSExtension']['NSExtensionPrincipalClass'] == 'FinderPackExtension.FinderSync'
symbols = subprocess.check_output(['nm', '-u', str(extension / 'Contents/MacOS/FinderPackExtension')], text=True)
assert '_NSExtensionMain' in symbols, 'Extension entry point is missing'
launch = plistlib.loads((app / 'Contents/Library/LaunchAgents/FinderPackAgent.plist').read_bytes())
assert (app / launch['BundleProgram']).is_file(), 'Launch agent executable is missing'
assert launch['MachServices'] == {app_info['FinderPackService']: True}, 'Mach service mismatch'
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
print('Bundle layout, versions, entry points, linkage, entitlements and nested signatures verified.')
