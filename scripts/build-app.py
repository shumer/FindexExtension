#!/usr/bin/env python3
"""Compile and assemble the application using Command Line Tools only."""
import argparse
import json
import os
import plistlib
import re
import shutil
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parent.parent
os.chdir(root)
parser = argparse.ArgumentParser()
parser.add_argument('--release', action='store_true', help='Require Developer ID signing for distribution')
args = parser.parse_args()
subprocess.run(['python3', str(root / 'scripts/fetch-dependencies.py')], check=True)
config = json.loads((root / 'Config/build.json').read_text())
name = config['name']
prefix = config['bundleIdentifier']
minimum = config['deploymentTarget']
version = (root / 'VERSION').read_text().strip()
if not re.fullmatch(r'[A-Za-z][A-Za-z0-9]*', name):
    raise SystemExit('Invalid product name')
if not re.fullmatch(r'[A-Za-z0-9]+(?:\.[A-Za-z0-9-]+)+', prefix):
    raise SystemExit('Invalid bundle identifier')
if not re.fullmatch(r'\d+\.\d+\.\d+', version):
    raise SystemExit('VERSION must contain three components')

def capture(*command):
    return subprocess.check_output(command, text=True).strip()

def run(*command):
    subprocess.run([str(item) for item in command], check=True)

identities = capture('security', 'find-identity', '-v', '-p', 'codesigning')
known = re.findall(r'\b([A-Fa-f0-9]{40}) "(Developer ID Application:[^\n]+)"', identities)
requested = os.environ.get('CODESIGN_IDENTITY', '')
identity = None
if requested != '-':
    identity = next(((digest, label) for digest, label in known
                     if not requested or requested in (digest, label)), None)
    if requested and identity is None:
        raise SystemExit('Requested Developer ID identity is unavailable')
team = os.environ.get('DEVELOPMENT_TEAM', '')
if identity:
    match = re.search(r'\(([A-Z0-9]{10})\)$', identity[1])
    if not match:
        raise SystemExit('Cannot derive team from Developer ID certificate; inspect its identity')
    if team and team != match[1]:
        raise SystemExit('DEVELOPMENT_TEAM does not match the selected signing identity')
    team = match[1]
if team and not re.fullmatch(r'[A-Z0-9]{10}', team):
    raise SystemExit('Invalid DEVELOPMENT_TEAM')
if args.release and not identity:
    raise SystemExit('Distribution requires an available Developer ID Application identity')
# Ad-hoc builds are inspectable artifacts, never authenticated service installations.
team = team or 'LOCAL'
group = f'{team}.{prefix}'
service = f'{group}.agent'
sdk = capture('xcrun', '--show-sdk-path')
sdk_version = capture('xcrun', '--show-sdk-version')
architecture = capture('uname', '-m')
if architecture not in ('arm64', 'x86_64'):
    raise SystemExit('Unsupported build architecture')
architectures = ['arm64', 'x86_64'] if args.release else [architecture]
number = capture('git', 'rev-list', '--count', 'HEAD')
source_commit = capture('git', 'rev-parse', 'HEAD')
work = root / '.build/clt'
work.mkdir(parents=True, exist_ok=True)
(root / '.build/module-cache').mkdir(exist_ok=True)
common = ['xcrun', 'swiftc', '-swift-version', config['swiftVersion'],
          '-strict-concurrency=complete', '-warnings-as-errors', '-O',
          '-sdk', sdk, '-target', f'{architecture}-apple-macos{minimum}',
          '-module-cache-path', str(root / '.build/module-cache'), '-parse-as-library']
link_flags = ['-Xlinker', '-platform_version', '-Xlinker', 'macos',
              '-Xlinker', minimum, '-Xlinker', sdk_version]
def compiler_for(target_architecture):
    result = common.copy()
    result[result.index('-target') + 1] = f'{target_architecture}-apple-macos{minimum}'
    return result

libraries = {}
for target_architecture in architectures:
    target_work = work / target_architecture
    target_work.mkdir(exist_ok=True)
    core = target_work / 'libFinderPackCore.a'
    run(*compiler_for(target_architecture), '-emit-library', '-static', '-emit-module', '-module-name', 'FinderPackCore',
        '-emit-module-path', target_work / 'FinderPackCore.swiftmodule',
        *sorted((root / 'Sources/FinderPackCore').glob('*.swift')), '-o', core)
    libraries[target_architecture] = core

stage = work / f'{name}.app'
if stage.exists():
    shutil.rmtree(stage)
bundles = {
    'App': stage,
    'Agent': stage / f'Contents/Library/Helpers/{name}Agent.app',
    'Extension': stage / f'Contents/PlugIns/{name}Extension.appex',
}
for kind, bundle in bundles.items():
    product = name if kind == 'App' else name + kind
    module = product
    executable = bundle / 'Contents/MacOS' / product
    executable.parent.mkdir(parents=True, exist_ok=True)
    (bundle / 'Contents/Resources').mkdir(exist_ok=True)
    translations = json.loads((root / 'Resources/Translations.json').read_text())
    for language in ['en', 'ru', 'uk', 'pl']:
        localized = bundle / 'Contents/Resources' / (language + '.lproj')
        localized.mkdir(exist_ok=True)
        def quoted(text):
            return json.dumps(text, ensure_ascii=False)
        lines = [quoted(key) + ' = ' + quoted(key if language == 'en' else values[['ru', 'uk', 'pl'].index(language)]) + ';'
                 for key, values in translations.items()]
        (localized / 'Localizable.strings').write_text('\n'.join(lines) + '\n')
        if kind == 'Agent':
            usage = 'FinderPack reads Finder selections for shortcuts and opens terminal sessions when requested.'
            description = usage if language == 'en' else translations[usage][['ru', 'uk', 'pl'].index(language)]
            (localized / 'InfoPlist.strings').write_text(quoted('NSAppleEventsUsageDescription') + ' = ' + quoted(description) + ';\n')

    extra = ['-application-extension', '-Xlinker', '-e', '-Xlinker', '_NSExtensionMain'] if kind == 'Extension' else []
    if kind == 'App':
        framework_parent = bundle / 'Contents/Frameworks'
        framework_parent.mkdir(exist_ok=True)
        shutil.copytree(root / '.build/dependencies/Sparkle/Sparkle.framework', framework_parent / 'Sparkle.framework', symlinks=True)
        extra += ['-F', str(root / '.build/dependencies/Sparkle'), '-framework', 'Sparkle',
                  '-Xlinker', '-rpath', '-Xlinker', '@executable_path/../Frameworks']
    slices = []
    for target_architecture in architectures:
        target_work = work / target_architecture
        output_binary = executable if len(architectures) == 1 else target_work / (product + '-binary')
        run(*compiler_for(target_architecture), '-module-name', module, '-I', target_work,
            *sorted((root / 'Shared').glob('*.swift')), *sorted((root / kind).glob('*.swift')),
            libraries[target_architecture], *link_flags, *extra, '-o', output_binary)
        slices.append(output_binary)
    if len(slices) > 1:
        run('lipo', '-create', *slices, '-output', executable)
    replacements = {
        'EXECUTABLE_NAME': product, 'PRODUCT_NAME': product, 'PRODUCT_MODULE_NAME': module,
        'PRODUCT_BUNDLE_IDENTIFIER': prefix + ({'App': '', 'Agent': '.agent', 'Extension': '.extension'}[kind]),
        'MARKETING_VERSION': version, 'CURRENT_PROJECT_VERSION': number,
        'MACOSX_DEPLOYMENT_TARGET': minimum, 'DEVELOPMENT_TEAM': team,
        'FINDERPACK_BUNDLE_PREFIX': prefix, 'FINDERPACK_GROUP': group, 'FINDERPACK_SERVICE': service,
    }
    def expand(value):
        if isinstance(value, dict):
            return {key: expand(item) for key, item in value.items()}
        if isinstance(value, list):
            return [expand(item) for item in value]
        if isinstance(value, str):
            return re.sub(r'\$\(([^)]+)\)', lambda match: replacements[match[1]], value)
        return value
    info = expand(plistlib.loads((root / f'Config/{kind}-Info.plist').read_bytes()))
    info['CFBundleInfoDictionaryVersion'] = '6.0'
    info['CFBundleSupportedPlatforms'] = ['MacOSX']
    info['NSHighResolutionCapable'] = True
    info['CFBundleLocalizations'] = ['en', 'ru', 'uk', 'pl']
    info['FinderPackSourceCommit'] = source_commit
    if kind == 'App':
        public_key = os.environ.get('SPARKLE_PUBLIC_KEY', '')
        if public_key:
            import base64
            if len(base64.b64decode(public_key, validate=True)) != 32:
                raise SystemExit('Invalid Sparkle public key')
            info['SUPublicEDKey'] = public_key
            info['SUFeedURL'] = 'https://github.com/shumer/FindexExtension/releases/latest/download/appcast.xml'
            info['SUEnableAutomaticChecks'] = False
            info['SUVerifyUpdateBeforeExtraction'] = True
    info['FinderPackBuildKind'] = 'developer-id' if identity else 'ad-hoc'
    (bundle / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
    entitlements = expand(plistlib.loads((root / f'Config/{kind}.entitlements').read_bytes()))
    (work / f'{kind}.entitlements').write_bytes(plistlib.dumps(entitlements))

launch_directory = stage / 'Contents/Library/LaunchAgents'
launch_directory.mkdir(parents=True, exist_ok=True)
launch = {
    'Label': service,
    'BundleProgram': f'Contents/Library/Helpers/{name}Agent.app/Contents/MacOS/{name}Agent',
    'MachServices': {service: True}, 'RunAtLoad': True,
    'ProcessType': 'Interactive', 'LimitLoadToSessionType': 'Aqua',
}
(launch_directory / f'{name}Agent.plist').write_bytes(plistlib.dumps(launch))
framework = stage / 'Contents/Frameworks/Sparkle.framework'
components = [framework / 'Versions/B/Autoupdate',
              framework / 'Versions/B/XPCServices/Downloader.xpc',
              framework / 'Versions/B/XPCServices/Installer.xpc',
              framework / 'Versions/B/Updater.app', framework]
for component in components:
    signing = ['codesign', '--force', '--sign', identity[0] if identity else '-',
               '--preserve-metadata=identifier,entitlements', '--options', 'runtime']
    if identity:
        signing += ['--timestamp']
    run(*signing, component)
for kind in ['Agent', 'Extension', 'App']:
    signing = ['codesign', '--force', '--sign', identity[0] if identity else '-',
               '--options', 'runtime', '--entitlements', str(work / f'{kind}.entitlements')]
    if identity:
        signing += ['--timestamp']
    run(*signing, bundles[kind])
    run('codesign', '--verify', '--strict', bundles[kind])
    if identity:
        details = subprocess.run(['codesign', '-dv', str(bundles[kind])], capture_output=True, text=True, check=True).stderr
        if f'TeamIdentifier={team}' not in details:
            raise SystemExit('Signed bundle team does not match configuration')
run('codesign', '--verify', '--deep', '--strict', stage)
output = root / 'build' / f'{name}.app'
output.parent.mkdir(exist_ok=True)
if output.exists():
    shutil.rmtree(output)
shutil.copytree(stage, output, symlinks=True)
print(f"Built {output} ({version}, build {number}, {'+'.join(architectures)}, SDK {sdk_version})")
print('Developer ID signed.' if identity else 'Ad-hoc development artifact; authenticated XPC requires Developer ID signing.')
