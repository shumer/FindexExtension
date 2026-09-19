# 0004: Menu preferences, pinned destinations and setup status

Status: accepted.

Menu customization adds optional fields to preference schema version 1. Older files
load with every command visible and no pinned folders. Hiding a command affects
Finder menus only; it does not delete templates or change recorded shortcuts.
Command IDs come from a fixed allowlist. Empty command groups are omitted.
Catalog failures keep the last validated menu preferences rather than restoring
all commands to defaults while the helper is unavailable.

Pinned folders have stable UUIDs, optional display labels and local file URLs. At
most 20 are stored, with distinct IDs and normalized paths. Preserve the original
URL before validation so normalization cannot turn a remote host into a local path.
Favorites precede the five recent folders; normalized duplicates are shown once.
No file system lookup takes place while constructing a Finder menu. Existing move
validation checks the destination at execution time and fails if it disappeared.
Removing a pin changes preferences only. Folder renames are not tracked by bookmarks.

A dedicated authenticated setup request reports the helper's permission status.
It reads notification authorization, Core Graphics event-posting access and Finder
Automation permission without prompting. Apple Event permission checks run off the
main actor; notification settings use their asynchronous API. Unknown status remains
unknown. The app distinguishes helper registration, pending background approval and
an actual response, and polls while the Setup page is visible.

Permission requests are separate, explicit button actions with fixed targets. The
app never reports its own permissions as the helper's and never prompts just because
the Setup page opened. Optional permissions do not block ordinary file actions.
The setup client and permission client are separate from file operations and the
notification authorization request, so a permission dialog cannot occupy their XPC
connection. An Automation prompt can wait up to five minutes.

Sources: the installed Apple SDK's AppleEvents.h and
https://developer.apple.com/videos/play/wwdc2019/701/ describe non-prompting Automation
checks; https://developer.apple.com/documentation/usernotifications/unusernotificationcenter
provides asynchronous notification settings.
