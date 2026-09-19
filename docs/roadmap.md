# Roadmap

## Implemented

- Command Line Tools build, Swift 6 strict concurrency and authenticated asynchronous XPC.
- Developer ID signing, local notarization and stapling of the app.
- Selected native design A with direct Finder menu groups.
- Nine path formats, configurable separators and cached Git discovery.
- Shared preferences and template catalog with one-time default seeding.
- File and directory templates, UTF-8/UTF-16 placeholder expansion, exclusive creation,
  custom labels/icons/order, import, editor and Trash removal.
- Installed application discovery, terminal/editor adapters and explicit permission controls.
- Move/copy journal, verified cross-volume copying, retained originals, conflict choices,
  progress/cancellation, clipboard intent, recent destinations and conditional batch undo.
- Native settings, optional shortcuts and product strings in four languages.
- Pinned Sparkle framework, update key validation and signed appcast generation scripts.
- Source/build CI and a fail-closed, manual signed-release workflow that creates a draft.
- README with installation, development, recovery and release setup instructions.

## Verification completed

- Installed app/agent/extension XPC round trips and rejection of an unrelated signed client.
- Finder toolbar, item, container, sidebar and external USB menu entry points.
- Installed path copying and regular template creation with numbered collisions.
- 70 core checks including a separate mounted APFS volume, ACL/xattr preservation,
  unchanged-source copying, move/undo, cancellation and interrupted journal recovery.
- Strict typechecking of all three targets.
- Universal Developer ID build and successful GitHub source/build jobs.
- Sparkle appcast generation and independent ZIP signature verification with ephemeral keys.
- Signed/notarized/stapled universal app and DMG, mounted image validation and checksums.
- Installed Russian settings, template creation, Move To/undo, Cut/Paste and Move/undo.
- English/Polish/Ukrainian settings spot checks, Russian light/dark menu and template editor,
  sidebar arrow-key navigation and successful notification permission grant.
- Opening the isolated text fixture through the Sublime Text adapter.
- Separate notification setup connection with a five-minute permission wait and localized status.
- Signed GitHub release workflow for v0.1.0 build 8, including credential validation,
  app/DMG notarization and a draft with all five assets. Downloaded archive signature,
  checksums, app signature and tickets independently verified.

- Real Sparkle update from installed CI build 8 to notarized build 9 through a loopback
  feed, with the helper and Finder extension active. Automatic reconnection, extension
  replacement, data preservation and post-update file creation passed.

- Published v0.1.0 build 8 and checked anonymous DMG download and the public latest feed.

## Remaining acceptance gates

- Expand installed action coverage beyond the verified template creation and move/undo flows.
- Verify third-party terminal adapters with their applications installed.
- Complete keyboard traversal, VoiceOver and remaining dialogs across all four locales.
  Initial locale and light/dark spot checks passed; see verification evidence.
- Check notification permission denial/delivery and shortcut Automation prompts.
- Check macOS 14/15/26 and Intel runtime compatibility, cloud/network files and hotplug.
- Verify public update installation on another Mac. The local two-build lifecycle
  passed using a loopback feed; anonymous public feed and artifact delivery were checked.
- Complete quarantined-download, clean-machine installation and removal checks.
- Complete remaining acceptance checks for the initial public release, then add a Homebrew cask.

Compilation, notarization and core tests do not replace installed UI or compatibility testing.

## Hidden-file visibility

- Added Show/Hide Hidden Files to Finder menus and Menu settings, using Finder's
  native shortcut without restarting Finder or writing its preferences.
- A neutral title avoids incorrectly representing transient Finder state.
- Added localized permission handling and nine core command-contract checks.
- Installed command delivery passed from Menu settings, blank-space and file context
  menus, and the Finder toolbar. Finder kept PID 577 throughout.
- Published in v0.1.1 build 13 after signed CI, independent asset verification and
  a successful public Sparkle update from local build 11.

## Menu and setup usability

- Individual command and template visibility, with backward-compatible preferences.
- Up to 20 pinned move destinations with labels, ordering and recent-folder deduplication.
- Dedicated setup status, non-prompting helper permission checks and repair controls.
- All 101 core checks and the signed universal CLT build passed.
- Installed acceptance passed for granular command/template visibility, pinned-folder
  moves and undo, and disconnected/connected setup status. User preferences restored.
- Local build 14 is notarized and installed. Release 0.1.2 packages these improvements.
- Reworked the README around installation and first use, with real interface screenshots,
  separate usage/development guides and English screenshots.
