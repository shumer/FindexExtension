# Verification record

Date: 2026-09-19.

Current status: universal build 6 is installed, and its app and DMG are notarized and
stapled. See the final package section below. Earlier sections preserve historical results
and blockers that may since have been resolved.

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

## Latest build and CI evidence

Source commit: `cd74ea9`. Local output: version 0.1.0, build 4, arm64 and x86_64, SDK 27.0.
The universal app, agent, extension and nested Sparkle components passed Developer ID,
hardened runtime, timestamp and strict signature verification.

[GitHub Checks run 35408495513](https://github.com/shumer/FindexExtension/actions/runs/35408495513)
passed both source and build jobs. This includes 70 checks with the separate APFS fixture,
Swift typechecking and an ad-hoc inspection ZIP. The first run exposed a Swift 6.3.3 compiler
IR generation crash caused by a direct actor-isolated method reference in a SwiftUI Binding.
An explicit closure fixed it without disabling optimization or concurrency checks.

Update tooling was tested with an ephemeral Curve25519 signing key: matching keys passed,
missing and mismatched keys failed cleanly. Sparkle generated an appcast from a temporary
application ZIP, and an independent CryptoKit check verified its EdDSA signature against
those exact archive bytes. No production key was generated, exported or persisted. This
verifies feed tooling, not the installed two-version update lifecycle.

The latest app is signed but NOT notarized. A fresh submission failed before returning an
ID because notarytool could not find Keychain profile `FinderPack`. The same failure occurred
with the login keychain specified explicitly. Earlier accepted submissions do not cover the
new binaries. Restore access to the profile and repeat notarization before packaging the
final DMG. Do not distribute the latest local app as a notarized release.

Outstanding external requirements: unlock the Mac for native UI checks, make the existing
notarization profile available, and provision the GitHub release secrets/public update key.

## Installed settings and file operations, 2026-09-19

Keychain profile FinderPack became available again. Universal build 5 was accepted under
submission `57899ea7-845a-4119-8650-d9e67edcbdfe`, stapled and accepted by Gatekeeper. The old
helper was unregistered through its UI before replacing the app. The new app was installed
in Applications, its helper connected, and the Finder extension stayed enabled without
restarting Finder.

Installed checks passed for the Russian settings sections, template content loading,
application discovery, Finder's four menu groups and asynchronous Git-relative availability.
Creating Markdown from Finder produced the expected expanded filename and selected the
result. Move To opened a folder panel and moved the test file. Settings showed the journal
entry; Undo restored the original path and exact content.

A temporary shortcut could be recorded and cleared. System-wide invocation was not
confirmed through the UI tool and remains a manual acceptance item. Opening Terminal was
requested through Finder, but the tool prohibits inspecting Terminal, so its working
folder is not counted as verified. All file operations used `build/runtime-0991939e` fixtures.

Russian inspection exposed a truncated Shortcuts sidebar label. The sidebar and recorder
were widened, with the final installed layout check recorded below when completed. CI
Actions were updated to official v7.0.1 releases and pinned to their exact commit hashes.

## Final local package, build 6

Source commit: `9c5b2b11cf73c44b9c80b5597af02a99bfee46fe`.
Version 0.1.0, build 6, universal arm64/x86_64, Command Line Tools, Swift 6.4 and SDK 27.0.

- App submission `34bfde5c-d473-414f-b38f-5c9f8a9c9c50`: Accepted.
- DMG submission `11624070-9a3a-45e6-b6b8-99a37000f057`: Accepted.
- Both tickets were stapled and validated; Gatekeeper accepted the app and DMG.
- Mounted the DMG read-only and verified its embedded app ticket, Gatekeeper assessment,
  matching bundle metadata and Applications symlink. Detached the image afterward.
- SHA-256 checks passed for `build/FinderPack-0.1.0-6.zip` and `.dmg`.
- Build evidence is in `build/build-info.json`; checksums are in `build/SHA256SUMS`.
- Installed build 6 after unregistering the previous helper. Registration and the diagnostic
  XPC/shared-container round trip passed again. Finder was not restarted.
- The Russian Shortcuts sidebar label now fits. All sidebar section labels are visible.
- Finder Cut, Paste and Move, and Undo Last Move passed on the isolated sample file with
  exact content restored. The temporary recorded shortcut was cleared after testing.

[GitHub Checks run 35424378724](https://github.com/shumer/FindexExtension/actions/runs/35424378724)
passed with the pinned v7.0.1 Actions. These artifacts are local test candidates, not a
published stable release. Remaining gates include the real two-version Sparkle lifecycle,
system shortcut activation, permission-denial flows, additional locales/accessibility,
third-party adapters and clean-machine/other-OS compatibility. GitHub release secrets and
production update keys are still not configured.


## Settings and permissions acceptance, 2026-09-19

Checks used installed build 6 on the local Apple Silicon Mac.

- Retried the notification request. After the user allowed it, the app reported
  "Notifications enabled." Delivery of a success banner and the denied-permission
  path are not yet confirmed.
- The first request exposed a 15-second client timeout while macOS was still waiting
  for a user decision. The client now allows five minutes for notification requests
  and application launches that can display an Automation prompt. Notification setup
  uses a separate connection, disables duplicate requests, displays a waiting message,
  and reports a permission-specific failure instead of suggesting a file operation retry.
- Switched the installed app through English, Polish and Ukrainian using the per-app
  macOS language setting, then removed that override to restore Russian. Inspected
  menu and shortcut controls through accessibility and checked English menu/templates,
  Polish shortcuts and Ukrainian shortcuts visually. This is not exhaustive coverage
  of every dialog in every language.
- Checked Russian menu and template editor in dark appearance, then restored the
  original light appearance. Visible controls and editor content remained readable.
- Sidebar arrow-key navigation moved from Menu to Templates and Applications.
  Localized controls, template content and shortcut recorder were exposed in the
  accessibility tree. Full keyboard traversal and VoiceOver speech/navigation remain
  acceptance items. VoiceOver briefly reported enabled, then returned to disabled;
  its navigation could not be confirmed through the UI session.
- The FinderPack item-context menu opened the exact isolated Destination/Text.txt file
  in Sublime Text. Confirmed its file URL in the editor window. Other editor and terminal
  adapters are not implied by this result.
- Recorded a temporary Control-Option-Command-K shortcut (shown as Cyrillic L under
  the Russian keyboard layout) for the user to test with a physical key press.
  Do not count synthetic key delivery as proof of Carbon shortcut handling.

The permission change passed 64 core checks, strict Swift typechecking and a universal
Developer ID build. The rebuilt candidate is separate from installed build 6; delayed
prompt behavior still needs a first-use check with that candidate. No stable release
or production update key was created during these checks.


## First signed GitHub release candidate, 2026-09-19

[Release workflow 35436674999](https://github.com/shumer/FindexExtension/actions/runs/35436674999)
completed successfully for tag `v0.1.0`, source `4979c710f27d0952d3a659fd7d79fb08a3391407`.
Version 0.1.0, build 8, universal arm64/x86_64, Swift 6.3.3 and SDK 26.5.

- All six environment secrets were present. Sparkle key-pair validation, certificate
  import and Apple credential validation passed without exposing private values.
- App notarization: `832d68d3-21d8-4660-86d0-93bd06d98c0a`, Accepted.
- DMG notarization: `22e721d7-0406-48ea-9159-6603f8263d00`, Accepted.
- Packaging, stapling, archive signing, feed generation and credential cleanup passed.
- The unpublished draft contains `FinderPack-0.1.0-8.zip`, `FinderPack-0.1.0-8.dmg`,
  `SHA256SUMS`, `build-info.json` and `appcast.xml`.
- Downloaded all draft assets and notarization evidence into
  `build/ci-release-35436674999`. Both archive checksums matched.
- The extracted application passed strict nested signature verification and Gatekeeper
  assessment as Notarized Developer ID. App and DMG stapled tickets validated locally.
- Independently verified the downloaded ZIP's Ed25519 signature with CryptoKit against
  the public key embedded in the app. The key, source commit, build number and feed
  archive length matched the expected release metadata.

The draft has not been published, and its feed is not yet publicly available. This run
verifies the release pipeline, not installation or the two-version update lifecycle.
Installed build 6 was not replaced during this run.


## Installed Sparkle lifecycle, 2026-09-19

Installed CI build 8 from the downloaded, verified v0.1.0 draft. Before replacement,
archived build 6 in `build/update-acceptance/installed-build6.zip`, disconnected its
helper through Settings and quit the app. The previous bundle was retained at
`/private/tmp/FinderPack-before-ci8-35436674999.app`. The shared application data backup
completed after the user granted macOS container access, before the Sparkle upgrade.
Build 8 connected its helper and passed the diagnostic/shared-container check. Its
Finder extension created `Markdown.md` with the expected expanded content in the
isolated `build/runtime-0991939e/Destination` fixture directory.

Built version 0.1.0, build 9 from `dee7e6a993f99ad0c7eedd657ab7668088a208a0`, with the
same production Sparkle public key, Developer ID team and bundle identifiers. This is
a local test candidate, not a replacement for the immutable CI draft assets.

- 64 core checks, source checks and universal CLT build passed with Swift 6.4/SDK 27.0.
- Build 9 notarization `ab52aa2e-42bf-413d-b473-858a9e5ae842`: Accepted, stapled and
  validated. Evidence: `build/notary/submission.k8wcf2`.
- Created `build/update-acceptance/feed/FinderPack-0.1.0-9.zip` from the stapled app
  and signed the archive using the existing FinderPack Ed25519 key.
- Served only the fixture feed and archive on `127.0.0.1:8941`. Temporarily set the
  documented Sparkle `SUFeedURL` user-default override for the installed app. Its
  signed bundle and embedded production feed URL were not changed.
- Build 8's standard Check for Updates UI offered build 9. Selected Install Update,
  then Install and Relaunch. Sparkle downloaded, verified, extracted and installed
  the update, and relaunched FinderPack showing `0.1.0 (9)`.
- Helper PID changed from 6475 to 7786 and extension PID from 6402 to 7783. No manual
  unregister/register or extension termination was performed during the 8-to-9
  update. The reconnect marker was cleared, no Connect prompt appeared, and the
  post-update diagnostic/shared-container check passed.
- App, embedded agent and extension all report build 9. Installed app strict nested
  signature verification, stapled-ticket validation and Gatekeeper assessment passed.
- All 14 backed-up preference, recent-destination, template and recovery-journal files
  matched byte for byte after the update. The updated extension created valid JSON
  in the isolated fixture folder.
- A second update check against the same local feed reported the application current.
- Removed the temporary feed override, stopped the loopback server and relaunched
  FinderPack. Build 9 remains installed with its original production feed configuration.

The GitHub draft remains unpublished. This verifies the real Sparkle installation and
helper/extension lifecycle on this Mac, but not public HTTPS delivery, clean-machine
installation, Intel execution or other macOS versions. It does not replace the remaining
accessibility, permission-denial and adapter acceptance checks.

Sparkle documents the temporary feed override in its
[updater API](https://sparkle-project.org/documentation/api-reference/Classes/SPUUpdater.html).

## Public release and reinstall handoff, 2026-09-19

Published [v0.1.0 build 8](https://github.com/shumer/FindexExtension/releases/tag/v0.1.0)
at 10:31:36 UTC following the owner's explicit request. The five verified CI assets
were preserved unchanged. The public release notes explain installation and remaining
runtime-acceptance limits.

Before the handoff, disconnected the helper in Settings, quit FinderPack, unregistered
its extension, and moved the installed build 9 and remaining generated app bundles to
the macOS Trash. Preferences, templates and recovery history were retained. The owner
will download the DMG in a browser and test the normal downloaded-app launch path.
This is a reinstall on the development Mac, not a clean-machine or fresh-permissions test.

Downloaded the DMG anonymously from its public version-specific URL and confirmed its
SHA-256 matches the verified CI asset. The public `releases/latest/download/appcast.xml`
URL resolves successfully and advertises the expected version-specific build 8 ZIP.
The local anonymous-download checks are in `build/public-release-check`.
