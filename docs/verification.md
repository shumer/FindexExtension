# Verification record

Date: 2026-09-19.

## Environment

Active developer directory: `/Library/Developer/CommandLineTools`.
Swift 6.4, macOS SDK 27.0, host architecture arm64, minimum deployment target 14.0.
Full Xcode and XcodeGen are not required. No private key was exported. The signed prototype is installed in `/Applications/FinderPack.app`,
its agent is registered and its extension is enabled. Finder was not restarted.

## Reference inspection

Local DevDeck is `/Users/ashumenko/Projects/Shumer/widgets`; local iCalendar is its sibling.
Both build scripts and release workflows match the files fetched from GitHub by SHA-256.
DevDeck v0.17 and iCalendar v0.3 release workflows completed successfully. The iCalendar
v0.3 job specifically completed certificate import, app notarization and DMG notarization;
the ad-hoc fallback step was skipped.

- [DevDeck v0.17 run](https://github.com/shumer/DevDeck/actions/runs/35349420642)
- [iCalendar v0.3 run](https://github.com/shumer/iCalendar/actions/runs/35396617756)

GitHub returned no repository secrets from `gh secret list -R shumer/FindexExtension`.
No secret values were requested. Existing secrets in another repository are not automatically
inherited and cannot be downloaded from GitHub for reuse.

## Local evidence

- 22 core checks pass, including actual shell argument/file round trips, hostile names,
  dotfiles, relative boundaries and message validation.
- App, agent and extension passed Swift 6 typechecking with warnings as errors and macOS 14 target.
- `CODESIGN_IDENTITY=- ./build.sh --no-install` built all three bundles with CLT.
- `./build.sh --release --no-install` built and signed all three bundles using the existing
  Developer ID Application identity, team `MW9955TT6R`, outside the restricted sandbox.
- Final output: `build/FinderPack.app`, version 0.1.0, build 1, arm64.
- Extension linked through `NSExtensionMain`; Mach-O metadata records macOS 14 minimum and SDK 27.
- All three executables link the core statically with no development-path dylib dependency.
- Nested signatures validate, with hardened runtime, Developer ID and secure timestamps.
- Extension entitlements contain sandbox, the resolved App Group and exact Mach lookup name.
- Launch plist points to the actual embedded helper and the matching service identifier.
- Source checks pass: Bash/YAML/JSON/plist syntax, documentation links and text checks.
- GitHub checks workflow now uses the CLT build entry point without XcodeGen or xcodebuild.
  These repository changes have not been pushed or run in GitHub Actions.

Restricted execution initially hid signing identities and reported incomplete signature
metadata. Repeating inspection outside that sandbox exposed the existing Developer ID and
valid entitlements. This was an execution-access limitation, not a missing certificate.

## Installed prototype

Verified on macOS 26.6.2 (25G83), arm64, on 2026-09-19:

- Installed the Developer ID build in Applications and opened its diagnostic window.
- Registered the agent with SMAppService. The app reported enabled and XPC ping succeeded.
- Enabled FinderPack in System Settings. The app then reported extension enabled.
- Finder displayed the toolbar button without restarting Finder.
- Toolbar, README.md item menu and docs folder item menu each returned the successful
  diagnostic response through the sandboxed extension. Confirmed in the visible alert
  and the extension's diagnostic log.
- Unregistered the agent, observed its process exit and not-registered status. After the
  callback fix, a connection check returned an error without terminating the app.
- Re-registered the agent and confirmed successful app and Finder requests again.
- Left the updated app installed, extension enabled and agent registered for continued work.

Runtime testing exposed two Swift 6 isolation crashes. Finder menu selectors run on a
callback queue, so selection is now captured there and only the client/UI work moves to
MainActor. Foundation XPC failure handlers now explicitly use Sendable closures before
hopping to MainActor. Repeated installed success and missing-agent checks verify the fixes.
No concurrency checks were disabled. The previous installed prototype is backed up at
`/tmp/FinderPack-before-thread-fix.zip`.

## Shared storage, authorization and volume checks

The diagnostic now writes a request-scoped marker in the App Group container. The agent
reads the client marker and writes a response marker; the client checks it and removes it.
The round trip passed for app/agent and sandboxed extension/agent. This tests actual shared
read/write access rather than only resolving a container URL.

`./scripts/check-xpc-rejection.sh` used a Developer ID signed executable from the same team
with the unrelated identifier `com.shumer.finderpack.untrusted-test`. Its method call was
rejected with NSCocoaErrorDomain 4097. The agent log independently recorded a dropped
check-in due to the code signing requirement. A transport error alone is not proof of
identity rejection; retain both observations when repeating the test.

Container-background and sidebar menus passed the diagnostic. External volume testing
on the USB FAT32 volume `NO NAME` first exposed missing menus with root-only monitoring.
Registering all mounted roots fixed it. The external folder menu then passed XPC and shared
container verification. No external-volume files were changed. Mount/unmount observers
were added; physical hotplug, network shares and cloud-provider coverage remain untested.

## Notarization

Used the existing Keychain profile `FinderPack` without exporting its credentials.

- Initial submission `751cf0d4-823e-4f9d-ada2-815b1d2b9942`: Accepted.
- Final submission after the external-volume fix:
  `3ae481cc-005d-4f21-9c31-3ddb5dcf3fd0`: Accepted.
- Final submission evidence: `build/notary/submission.8HtCD7/result.json`.
- Stapling and ticket validation passed for `build/FinderPack.app`.
- Installed the final stapled copy at `/Applications/FinderPack.app`.
- Ticket validation and Gatekeeper assessment passed for the installed copy:
  `source=Notarized Developer ID`.
- Re-registered the agent and repeated app and external Finder menu checks successfully.

This is a notarized engineering prototype, not a published product or a clean-machine
installation test. Rebuilding changed code invalidates this evidence for the new binary.

## Pending

Client rejection of an impersonating agent, physical hotplug, network/cloud coverage,
clean-machine downloaded installation, update lifecycle and other OS/CPU combinations.
The settings UI, remaining action groups and complete product acceptance are pending.
See prototype-checklist.md and the selected DesignSpec.


## First file actions, 2026-09-19

Owner selected proposal A: direct native action groups. Copy Path and New File now run
through the authenticated agent. The setup window remains an engineering harness.

Automated checks passed:

- 40 core checks, including 20 simultaneous exclusive file creations, collisions,
  template deletion persistence, source/destination symlink rejection, traversal rejection,
  binary preservation, filename substitution and invalid action requests.
- CLT release build, Swift 6 strict concurrency, warnings as errors, source checks and
  nested bundle/signature verification.
- Same-team unrelated XPC client rejected with NSCocoaErrorDomain 4097; the installed
  agent independently logged a dropped check-in due to its code signing requirement.

Manual checks on the installed macOS 26.6.2 arm64 build passed:

- Russian Copy Path and New File groups appear directly in the file context menu.
- Single-file absolute path matches the exact expected test path in the pasteboard.
- Three selected files produce exactly the expected shell-quoted path values.
- Markdown creation substitutes the actual filename and reveals/selects the result.
- A repeated toolbar request creates Markdown 2.md, preserving Markdown.md and the
  original sample file. The generated contents were verified from disk.
- Empty-folder background creation produces Text.txt in that folder and selects it.

An initial integration attempt exposed that representedObject did not carry the routing
value through Finder's reconstructed menu item. Routing now uses the preserved integer
menu tag and a bounded in-memory descriptor registry. The installed result, not merely
menu visibility, was checked after the fix.

Final action-build notarization: 2a87fe79-81f3-409c-b2f4-d79412ccc416, Accepted.
Evidence: build/notary/submission.ZIsDzY/result.json. Stapling and validation passed.
The installed /Applications/FinderPack.app passed Gatekeeper as Notarized Developer ID.
The agent is registered and the extension remains enabled. Finder was not restarted.
Previous prototype backup: /tmp/FinderPack-before-actions.zip.

Test data remains under build/action-smoke and build/action-empty. No existing user
files were used as creation targets. The clipboard contains generated test paths.

Not yet verified: notification delivery/permission UX, denied filesystem access UI,
external-volume file actions, template refresh during an open menu, inherited ACL policy,
crash/power-loss recovery, settings and accessibility acceptance. Directory templates,
custom metadata, alternate text encodings, git-root discovery and separator preferences
remain pending. Request receipts are retained without pruning in this prototype.


## Product implementation checks, 2026-09-19

The earlier sections record the installed action prototype, not acceptance of the latest UI.
The new settings, templates, application adapters, move UI, shortcuts and Sparkle integration
passed strict Swift 6 typechecking. Core checks now cover 64 scenarios on the host filesystem
and 70 with a separate mounted APFS fixture. The fixture verifies cross-volume move/undo,
ACLs and extended attributes. Additional checks cover directory templates, UTF-16, literal
replacement values, preference ordering, Git discovery, changed-file refusal, cancellation,
exclusive conflicts and interrupted journal reconstruction.

A transitional settings build was accepted by notarization under submission
`02c6a913-0f22-45fc-817b-49155c6f19a4`. Subsequent code changes require a fresh submission.
The currently installed app remains the earlier action prototype. The native UI tool reports
the Mac locked; latest UI installation, keyboard/locale/accessibility checks and terminal
adapter acceptance remain pending. No third-party terminal was installed for adapter tests.

GitHub repository signing secrets remain empty. The manual release workflow is implemented
but must receive credentials before it can run. Sparkle's real two-version update test and
clean-machine/other-OS acceptance are separate gates, not inferred from core tests.
