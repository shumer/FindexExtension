# ADR-0001: Command Line Tools build and isolated execution

Status: Accepted, supersedes the initial generated-project proposal.
Date: 2026-09-19.
Deciders: project owner, explicitly requiring the existing CLT approach.

## Context

DevDeck (local directory `widgets`) and iCalendar build without full Xcode. Their local
build scripts and release workflows match GitHub. Their successful release runs establish
an existing signing/notarization process. FinderPack adds an extension and a helper bundle.

## Decision

Use Command Line Tools directly through `swiftc`, with a static shared module and three
executables. Link the extension using `-application-extension` and `_NSExtensionMain`.
`build.sh` delegates deterministic bundle assembly, metadata expansion, signing and artifact
verification to small Python scripts. `Config/build.json` replaces the XcodeGen manifest.

Keep the same external build/signing conventions as the reference projects: VERSION,
commit-count build number, Developer ID discovery and `CODESIGN_IDENTITY=-` for ad-hoc.
Use explicit linker platform/SDK versions. Do not install as a side effect of a build.
The release mode requires Developer ID. The prototype is host-architecture only.

## Options considered

| Option | Benefit | Cost |
| --- | --- | --- |
| CLT direct compiler + scripts | Works on current machine, explicit extension entry point | Own bundle assembly and validation |
| SwiftPM + bundle scripts | Existing reference pattern, useful dependency resolution | Extension executable needs explicit entry/link setup |
| XcodeGen + full Xcode | Native project integration | Unnecessary new machine/tool requirement |

Direct compilation is sufficient for the dependency-free prototype. Introduce SwiftPM for
Sparkle/KeyboardShortcuts dependency resolution when integrated; preserve the CLT build
contract. The extension has already linked successfully with the installed CLT SDK.

## Consequences

Full Xcode is not a blocker. Bundle validation must check Info.plist, entry points, nested
signatures, static linkage and launch-service paths. Compilation is distinct from Finder
registration, authenticated XPC runtime and notarization. Keep those as explicit test gates.
The agent remains isolated and exposes a non-mutating diagnostic ping first.

## Follow-up

- [x] Build the three bundles using CLT.
- [x] Verify ad-hoc nested signatures and assembly.
- [ ] Validate Developer ID installed behavior and App Group access.
- [ ] Verify XPC rejection for an unrelated client and success for app/extension.
