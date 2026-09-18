# Prototype and release verification

No row is passed until an installed build has been exercised. Record date, OS, hardware,
build, steps and evidence. A ping prototype does not establish file-operation acceptance.

## Signed prototype gate

- [ ] Confirm identifiers, team, architecture and entitlements.
- [x] Build all targets with Command Line Tools and inspect bundle layout and signatures.
- [x] Install in Applications without overwriting a working unrelated app.
- [x] Enable extension through system settings; status updates when the app becomes active.
- [x] Register, unregister and re-register agent; enabled and not-registered states verified.
- [ ] Exercise approval-required and missing-service states deliberately.
- [x] App ping succeeds. Finder menu ping succeeds through sandbox boundary.
- [x] An unrelated same-team signed client is rejected, confirmed by agent signature log.
- [ ] The client rejects an unrelated agent.
- [x] Missing agent returns an error in the app without crashing.
- [ ] Verify the timeout branch and missing-agent feedback from Finder.
- [x] App Group read/write round trips pass for app/agent and extension/agent; Mach name resolves.
- [x] Local file/folder, container-background, sidebar, toolbar and external USB folder menus pass.
- [ ] Test iCloud, network volumes and physical hotplug.
- [ ] Unregister agent, confirm exit/no relaunch, remove app and check extension lifecycle.
- [x] Notarize, staple and validate the installed prototype with Gatekeeper.
- [ ] Test a downloaded/stapled prototype on a separate clean environment.

## Original edge-case matrix

| Case | Required observation | Status |
| --- | --- | --- |
| 1. Extension disabled | Onboarding gives actionable enablement | Not tested |
| 2. New installation | Detect missing registration, no automatic Finder restart | Not tested |
| 3. 1,000+ files | Correct context and measured menu latency | Not tested |
| 4. Hostile names | Exact paths, shell quoting, Unicode, RTL and newlines | Core subset only |
| 5. iCloud placeholders | No destructive operation on unavailable content | Not tested |
| 6. Network disconnect | Partial state and recovery reported | Not tested |
| 7. Read-only/ejected volume | Safe failure, no source deletion | Not tested |
| 8. App/package bundle | One logical item with preserved content | Not tested |
| 9. Symlinks and aliases | Move link itself | Not tested |
| 10. Trash/protected paths | Hidden or actionable rejection | Not tested |
| 11. No write permission | Safe failure with explanation | Not tested |
| 12. Full destination | Preserve source and recover staging | Not tested |
| 13. Self-descendant destination | Reject before mutation | Not tested |
| 14. Multiple Finder windows | Use correct invocation context | Not tested |
| 15. Language change | Defined, consistent refresh | Not tested |
| 16. Revoked Automation | Feature degrades, unrelated functions work | Not tested |
| 17. Agent crash | Bounded failure, recovery, no duplicate mutation | Not tested |
| 18. Update with running agent | Correct shutdown and new registration/version | Not tested |
| 19. Repeated invocation | No unintended duplicate mutation | Not tested |
| 20. OS differences | Availability guards and recorded compatibility | Not tested |

## Product acceptance

- [ ] Every NF/CP/OT/MV/EP/D requirement verified.
- [ ] VoiceOver and accessibility display preferences checked.
- [ ] en/ru/uk/pl checked with long labels and template names.
- [ ] Owner selects design; measured UI conforms to DesignSpec.
- [ ] Memory/startup/menu goals measured with methodology recorded.
- [ ] Undo after replacement, cancellation and external edits verified.
- [ ] Sparkle update between two signed/notarized versions verified.
- [ ] DMG, ZIP, appcast, checksums and cask match final assets.

| Operating system | Build | Installed runtime | Distribution/update |
| --- | --- | --- | --- |
| macOS 14 | Not tested | Not tested | Not tested |
| macOS 15 | Not tested | Not tested | Not tested |
| macOS 26.6.2 arm64 | CLT signed build passed | Local, sidebar, toolbar, USB menus and App Group passed | Notarization passed; update not tested |
| macOS 27 | Not tested | Not tested | Not tested |
