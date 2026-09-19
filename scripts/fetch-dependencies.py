#!/usr/bin/env python3
"""Fetch pinned build dependencies and verify their archive digests."""
import hashlib
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
config = json.loads((root / 'Config/dependencies.json').read_text())['sparkle']
cache = root / '.build/dependencies'
cache.mkdir(parents=True, exist_ok=True)
archive = cache / ('Sparkle-' + config['version'] + '.tar.xz')
if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest() != config['sha256']:
    subprocess.run(['curl', '--fail', '--location', '--silent', '--show-error', '--retry', '2', '--max-time', '120',
                    config['url'], '--output', str(archive)], check=True)
if hashlib.sha256(archive.read_bytes()).hexdigest() != config['sha256']:
    raise SystemExit('Sparkle archive checksum does not match the pinned release')
destination = cache / 'Sparkle'
destination.mkdir(exist_ok=True)
subprocess.run(['tar', '-xf', str(archive), '-C', str(destination)], check=True)
