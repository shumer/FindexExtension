# Build and contribute

[Back to the README](../README.md)

## Build locally

Command Line Tools are sufficient; full Xcode and a generated Xcode project are not required.
Python 3, Ruby and the system signing tools must be available. Builds download the pinned
Sparkle archive and verify its SHA-256 digest before use.

```sh
xcode-select --install
git clone https://github.com/shumer/FindexExtension.git
cd FindexExtension
./run-tests.sh
./scripts/typecheck-app.sh
./build.sh --release --no-install
```

A Developer ID Application identity with its private key must already be available in your
Keychain. The build discovers it and derives the team identifier. To choose an identity,
set `CODESIGN_IDENTITY` to its certificate name or SHA-1. No signing keys belong in the repo.

Output: `build/FinderPack.app`. The release build assembles universal binaries, signs nested
components first and verifies the complete bundle. It does not install or publish anything.

Notarize with your existing Keychain profile:

```sh
./scripts/notarise.sh build/FinderPack.app FinderPack
```

Then copy the stapled app into Applications and follow the [setup steps](../README.md#install-and-enable). When replacing
an installed development build, disconnect its helper in About before replacing the app,
then reopen it and reconnect. Do not restart Finder automatically.

For compilation and artifact inspection without signing credentials:

```sh
CODESIGN_IDENTITY=- ./build.sh --no-install
```

This ad-hoc build is not a distributable installation and cannot use the authenticated agent.

Keep inspection copies of release apps archived after verification. macOS can discover
and register extensions inside extracted build directories alongside the installed app.
Unregister an inspection extension before archiving its app; retain the immutable release
ZIP and DMG as evidence. Do not restart Finder as part of cleanup.

## CI and releases

[Checks](https://github.com/shumer/FindexExtension/actions/workflows/checks.yml) runs on pushes
to main and pull requests: source validation, core checks, strict Swift typechecking,
separate-volume recovery tests and an inspectable ad-hoc bundle.

[Signed release candidate](https://github.com/shumer/FindexExtension/actions/workflows/release.yml)
is manually dispatched on main with an existing `vX.Y.Z` tag. It verifies the tag against
VERSION and main history, enforces increasing build numbers, signs and notarizes the app,
creates a signed/notarized DMG and ZIP, signs the update archive, generates its appcast and
uploads immutable assets to a **draft** release. It never falls back to ad-hoc signing or
replaces published assets. Secrets are removed in an always-running cleanup step.

Configure the repository's `release` environment with these secrets:

- `DEVELOPER_ID_P12`: base64 certificate and private key.
- `DEVELOPER_ID_P12_PASSWORD`: exact P12 export password.
- `NOTARY_KEY_P8`: base64 App Store Connect API private key.
- `NOTARY_KEY_ID` and `NOTARY_ISSUER_ID`.
- `SPARKLE_PRIVATE_KEY`: Sparkle EdDSA private key in its exported base64 format.

Set repository variable `SPARKLE_PUBLIC_KEY` to the matching public key. The workflow checks
that the update keys match before importing the release certificate. See [release setup](release.md)
for key handling, publication order and recovery. The public v0.1.1 release completed this
workflow. Forks need their own signing identity and release credentials.

## Before a commit

Run `./run-tests.sh` and `./scripts/check-source.sh`. For application changes, also run
`./build.sh`. Use `./scripts/check-cross-volume.sh` for the separate-volume fixture.
See [repository rules](../CLAUDE.md), [architecture](architecture.md) and
[verification evidence](verification.md). Include a clear reproduction or a small
usage example with bug reports and pull requests. Never include signing keys.
