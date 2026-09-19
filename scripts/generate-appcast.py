#!/usr/bin/env python3
"""Sign the immutable update archive and generate its Sparkle feed."""
import os
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parent.parent
os.chdir(root)
private_key = os.environ.get('SPARKLE_PRIVATE_KEY', '')
if not private_key or not os.environ.get('SPARKLE_PUBLIC_KEY'):
    raise SystemExit('Sparkle signing keys are required for an update feed')
subprocess.run(['xcrun', 'swift', '-module-cache-path', str(root / '.build/module-cache'), 'scripts/check-update-key.swift'], check=True)
version = (root / 'VERSION').read_text().strip()
build = subprocess.check_output(['git', 'rev-list', '--count', 'HEAD'], text=True).strip()
name = f'FinderPack-{version}-{build}.zip'
stage = root / 'build/update-feed'
stage.mkdir(exist_ok=False)
shutil.copy2(root / 'build' / name, stage / name)
subprocess.run([str(root / '.build/dependencies/Sparkle/bin/generate_appcast'), '--ed-key-file', '-',
                '--download-url-prefix', f'https://github.com/shumer/FindexExtension/releases/download/v{version}/',
                str(stage)], input=private_key.encode(), check=True)
shutil.copy2(stage / 'appcast.xml', root / 'build/appcast.xml')
