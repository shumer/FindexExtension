# ADR 0002: Retained move data, native shortcuts and signed updates

Status: implemented, runtime acceptance pending for the new UI and update lifecycle.

## Decisions

Use an exclusive same-volume rename and a journaled cross-volume staging copy. Verify data,
mode, modification time, xattrs and ACLs. Retain the original on its volume instead of
removing the only recovery copy. Replacement first moves the existing destination to a
unique backup directory. A batch shares an identifier and undo runs in reverse order.

Undo checks the fingerprint and uses exclusive renames. An occupied original path or
changed content stops recovery. Interrupted records are reconciled using stored inode/device
identities as well as fingerprints. Recovery files are never purged automatically.

Use Carbon RegisterEventHotKey for two optional shortcut actions. This avoids an additional
package and works with the CLT assembly pipeline. Finder-only shortcuts register only while
Finder is frontmost. Explicit global shortcuts still operate on the front Finder window.
A constant AppleScript reads Finder selection as data and triggers Automation permission
only on use. No Accessibility permission or event interception is required.

Embed the pinned Sparkle binary framework, verify its archive SHA-256 and re-sign its nested
code inside out. Only builds with an EdDSA public key enable the updater. Release CI verifies
that the private/public keys match, signs the final stapled ZIP and produces a draft release.
Local Keychain notarization remains separate from GitHub secret provisioning.

## Consequences

Retained data consumes space and can require manual recovery after interrupted operations.
Filesystems that cannot preserve verified metadata fail safely. FileManager's active copy
cannot be interrupted mid-call; cancellation is checked at safe boundaries.

Shortcuts can conflict with other applications and require an open Finder window. Terminal
adapters and updater lifecycle still need runtime acceptance. No public release is implied
by successful signing or notarization.
