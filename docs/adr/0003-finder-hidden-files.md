# 0003: Native Finder hidden-file command

Status: accepted.

Finder menus and Menu settings expose Show/Hide Hidden Files without a checkmark.
The helper sends a fixed Command-Shift-Period key-down/key-up pair to Finder's PID
using Core Graphics. It never changes Finder preferences, terminates Finder or
reopens its windows. Accessibility permission is requested on first use. Missing
permission returns a localized explanation and leaves other commands available.

The menu title is deliberately neutral. Finder Sync's public interface and Finder's
AppleScript dictionary expose no live hidden-file visibility property. Installed
acceptance on macOS 26.6.2 showed the native shortcut revealing/hiding a test dotfile
while AppleShowAllFiles remained absent. This persisted preference cannot confirm
current visibility. Do not infer state from a local toggle counter either: users can
also press the native shortcut or another application can send it.

The agent advertises command support through an optional catalog capability field.
Older helpers do not advertise it, so newer menus disable the command until connected
to a supporting helper. Menu construction still uses only cached data. The action
accepts no paths, application identifiers, key codes or desired visibility state.
It uses the existing authenticated XPC connection and persistent request receipts,
so an interrupted request cannot automatically toggle Finder twice on retry.

A short asynchronous delay lets Finder dismiss the context menu before the event.
The helper activates Finder and waits for it to become active before sending events
to its PID. A short key-down/key-up interval allows its native event handling to run.
This also supports invocation from Settings. A successful reply
means the native command was sent, not that visibility was independently observed.
No optimistic checkbox, alternating title or misleading success notification is shown.

## Evidence

- Public Finder Sync API: https://developer.apple.com/documentation/findersync
- Public CGEvent PID targeting: https://developer.apple.com/documentation/coregraphics/cgevent/posttopid(_:)
- Installed Finder AppleScript dictionary:
  `/System/Library/CoreServices/Finder.app/Contents/Resources/Finder.sdef`.
- Installed acceptance details are recorded in `../verification.md`.
