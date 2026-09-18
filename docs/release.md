# Release procedure

Status: planned procedure, not a working release pipeline yet. The checks workflow builds source and ad-hoc bundles on PRs; no publication workflow is enabled until the signed prototype passes.

## Prerequisites

- Confirm product/bundle IDs, signing team, architectures and public download location.
- Command Line Tools with an explicitly selected Swift compiler and macOS SDK on the runner.
- Developer ID Application certificate including private key; matching entitlements and
  provisioning profiles if required by the chosen App Group configuration.
- Test installation, removal and updating from the previous version.

Store these in GitHub Actions secrets, never in source or chat:

| Secret | Purpose |
| --- | --- |
| DEVELOPER_ID_P12 | Base64 certificate and private key |
| DEVELOPER_ID_P12_PASSWORD | Export passphrase |
| NOTARY_KEY_P8 | Base64 App Store Connect team API private key |
| NOTARY_KEY_ID | Notary key identifier |
| NOTARY_ISSUER_ID | Issuer identifier |
| SPARKLE_PRIVATE_KEY | EdDSA archive signing private key |

Team ID, bundle IDs, public Sparkle key and appcast URL are configuration, not secrets.
Profile artifacts may need additional CI configuration once capabilities are verified.
Missing or partially configured credentials must fail public release; no ad-hoc fallback.

## Version policy

`VERSION` is the SemVer marketing version and supplies MARKETING_VERSION. All bundles share
one CURRENT_PROJECT_VERSION. Initial policy uses `git rev-list --count HEAD` from full
history. This is not intrinsically monotonic across branches or rewritten history:
releases come only from the protected main history, and CI must compare against the latest
published build and reject an equal/lower value. Rebuilds must not overwrite published assets.

## Proposed pipeline

1. Manually dispatch a release for an existing immutable tag, or push an explicitly designated
   release tag. Verify tag equals VERSION and belongs to the release history. Create/use a draft.
2. Checkout that exact tag with full history. Run source checks, unit tests and `./build.sh --release --no-install`.
   Record and control the actual developer directory/compiler/SDK; a runner label alone does not pin its SDK.
3. Import signing material into a temporary keychain. Configure noninteractive signing.
   Validate every required value, preserve passwords exactly, and clean keys/keychain with
   an always-running cleanup step. Never echo credentials.
4. Assemble bundles with Developer ID and per-target entitlements through the CLT build script. Verify embedded agent,
   extension and Sparkle code signatures, hardened runtime and timestamps. Do not repair
   a broken bundle by indiscriminate `codesign --deep` signing.
5. Submit the app in a `ditto` ZIP via notarytool. Require Accepted, retrieve logs on failure,
   staple the app and validate its ticket. Run codesign and Gatekeeper assessment.
6. Produce final update ZIP from the stapled app. Build/sign DMG with that app, background
   and Applications symlink; notarize/staple/validate the DMG as well.
7. Generate checksums and EdDSA signatures from final immutable bytes. Sign the archive,
   not the XML document. Generate appcast with correct version, OS floor and download URL.
8. Attach artifacts to the draft. Check metadata, installation and upgrade acceptance.
9. Publish the release, verify asset availability, then publish the appcast entry. A failure
   before this stage must leave the existing feed intact. Serialize releases to avoid races.

Do not run signing jobs against untrusted PR code. PR jobs need read-only permissions and no
release secrets. Deployment environments can gate publication separately from source checks.

## Manual artifact verification

```sh
codesign --verify --deep --strict --verbose=2 FinderPack.app
xcrun stapler validate FinderPack.app
spctl --assess --type execute --verbose=2 FinderPack.app
xcrun stapler validate FinderPack.dmg
```

These commands do not substitute for testing the downloaded, quarantined artifact on a clean
machine. Verify extension enablement, background approval, permission denial, working actions
and a real update between two versions. Preserve the evidence with the release.

## Recovery

Before publication, discard the failed draft artifacts and diagnose the notary/build logs.
After publication, stop advertising a broken update and retain immutable assets and evidence.
Ship a corrected version with a higher build number. Do not silently overwrite archives or
reuse an old appcast signature. A downgrade needs a separate compatibility/recovery plan.

## Reference differences

The supplied DevDeck workflow is single-bundle SwiftPM, ZIP-only, and permits ad-hoc fallback.
FinderPack adds nested targets, App Group, an agent lifecycle, DMG and Sparkle archive signing.
Its build script must not inherit automatic installation or destructive replacement of an
existing app. No installation notes should claim unsigned updates bypass platform security.

Sources: [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution),
[custom workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow),
[Sparkle](https://sparkle-project.org/documentation/).

## Local prototype notarization

An existing Keychain profile can submit the built app without exporting credentials:

```sh
./build.sh --release --no-install
./scripts/notarise.sh build/FinderPack.app FinderPack
```

The helper saves the submission result under `build/notary`, requires Accepted, staples
and validates the ticket, and assesses the app with Gatekeeper. Rebuilding afterward
requires a new submission for the changed binaries. This does not publish a release.
