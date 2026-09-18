# Roadmap

## Implemented foundation

- Repository rules, revised product scope, architecture decision and release procedure.
- Explicit runtime checklist covering the twenty original edge cases.
- Pure Swift path formatter and bounded, versioned diagnostic messages with core checks.
- CLT build for app, extension, agent and shared static module; explicit extension entry point.
- Diagnostic UI, service registration controls, asynchronous XPC ping with timeout and
  bidirectional signature requirements. App and Finder diagnostic requests pass on the installed macOS 26.6.2 prototype.
- Local build/typecheck/source-check entry points and source and ad-hoc-build CI definition.

## Next gate: signed prototype

- [ ] Confirm final product name, bundle prefix and developer team.
- [x] Compile, assemble and verify all three bundles with Command Line Tools.
- [x] Validate nested bundle layout, signed entitlements and installed diagnostic behavior.
- [ ] Install and verify the prototype checklist on a real Finder session.
- [ ] Verify monitoring coverage, XPC authentication and service lifecycle.
- [x] Complete Developer ID/notarization/stapling and installed Gatekeeper validation.
- [x] Verify shared storage and rejection of an unrelated signed client.
- [x] Verify container, sidebar and external USB menu entry points.

## Design

- [x] Prepare three interactive light/dark concepts; see [design concepts](design-concepts.md).
- [x] Record owner selection A and write [DesignSpec](DesignSpec.md) with proposed native UI tokens.
- [ ] Measure production settings UI and complete accessibility review.

## Core product

- [x] Implement eight copy formats through authenticated XPC with newline-separated results.
- [x] Add cached regular-file template menus, one-time seeding and exclusive numbered creation.
- [x] Localize action labels/errors in English, Russian, Ukrainian and Polish.
- [ ] Complete template trees, alternate text encodings, custom labels/icons and settings.
- [ ] Verify inherited ACL policy, interrupted writes and bounded request-receipt retention.
- [ ] Complete notification permission UX and verify notification delivery in each supported OS.


- [ ] Complete path formatting acceptance matrix and cached git discovery.
- [ ] Shared preferences, atomic template catalog, seeding and safe file creation.
- [ ] Application discovery/adapters and feature-scoped permissions.
- [ ] Settings, template editor and production onboarding.
- [ ] Move journal, conflict UI, verified cross-volume copy, undo/cancellation/recovery.
- [ ] Shortcut integration, feedback, four locales and accessibility.

## Distribution

- [ ] Pin release toolchain/dependencies and confirm supported CPU architectures.
- [ ] Add fail-closed release CI, nested signing, DMG and notarization.
- [ ] Add Sparkle, EdDSA secret/public key, appcast hosting and immutable publication.
- [ ] Exercise updating two installed versions with active agent/extension.
- [ ] Complete clean-machine, OS compatibility and removal checks.
- [ ] Publish stable release and Homebrew cask.

A Developer ID prototype has been built, installed and tested. The prototype is notarized and stapled. No public release has been published.
