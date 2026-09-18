#!/usr/bin/env python3
"""Check repository text, local documentation links and property-list syntax."""
import json
import plistlib
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
excluded = {'.git', '.build', 'build', '__pycache__'}
errors = []
count = 0
for path in root.rglob('*'):
    relative = path.relative_to(root)
    if any(part in excluded for part in relative.parts):
        continue
    if not path.is_file():
        continue
    if path.suffix not in {'.md', '.swift', '.sh', '.py', '.yml', '.json', '.plist', '.entitlements'}:
        continue
    text = path.read_text()
    count += 1
    for number, line in enumerate(text.splitlines(), 1):
        if re.search(r'[\u2010-\u2015]', line):
            errors.append(f'{relative}:{number}: typographic dash')
        if line.rstrip() != line:
            errors.append(f'{relative}:{number}: trailing whitespace')
    if path.suffix == '.json':
        json.loads(text)
    if path.suffix in {'.plist', '.entitlements'}:
        try:
            plistlib.loads(path.read_bytes())
        except Exception as error:
            errors.append(f'{relative}: {error}')
    if path.suffix == '.md':
        for target in re.findall(r'\]\(([^)]+)\)', text):
            if '://' in target or target.startswith('#'):
                continue
            destination = path.parent / target.split('#', 1)[0]
            if not destination.exists():
                errors.append(f'{relative}: broken link {target}')
if not re.fullmatch(r'\d+\.\d+\.\d+\n?', (root / 'VERSION').read_text()):
    errors.append('VERSION must be a three-component marketing version')
if errors:
    raise SystemExit('\n'.join(errors))
print(f'Checked {count} text files, documentation links and property lists.')
