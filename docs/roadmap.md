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

## Remaining acceptance gates

- Expand installed action coverage beyond the verified template creation and move/undo flows.
- Verify third-party terminal adapters with their applications installed.
- Check keyboard navigation, VoiceOver, light/dark appearance and four locales.
- Check notification permission denial/delivery and shortcut Automation prompts.
- Check macOS 14/15/26 and Intel runtime compatibility, cloud/network files and hotplug.
- Complete packaging and ticket checks for the final DMG.
- Supply release environment secrets and the Sparkle public variable, then run signed CI.
- Exercise a real update between two installed versions with the active helper/extension.
- Complete quarantined-download, clean-machine installation and removal checks.
- Publish a stable release and Homebrew cask after these gates pass.

Compilation, notarization and core tests do not replace installed UI or compatibility testing.
