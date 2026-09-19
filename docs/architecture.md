# Architecture

## Build

Command Line Tools compile the shared static module and three binaries. The extension
uses `NSExtensionMain` as its Mach-O entry point. `build.sh` assembles the containing app,
embeds the helper and extension, expands metadata and signs inside out. No Xcode project
or generator is required. `verify-bundle.py` checks the actual output.

## Process boundaries

Finder calls the sandboxed extension, which builds a menu from cached descriptors and
captures the current selection. An asynchronous XPC request goes to the per-user agent.
The agent validates the request, performs an allowlisted action and returns a typed result.
The main app owns onboarding, settings, template editing and update presentation.

The first prototype exposes only a diagnostic ping. It deliberately cannot move files,
run shell commands or replay actions through a custom URL. Runtime validation precedes
adding operations with side effects.

## Shared data

FinderPackCore is a pure Swift module. XPC transport is separate shared source compiled
into the three processes. This avoids loading execution code into the extension.
An App Group container will hold preferences, template catalog and templates. UserDefaults
alone is not an atomic multi-file database; catalog publication needs versioned snapshots.

For the prototype, use a macOS team-prefixed App Group and a Mach service beneath it.
The extension has an explicit temporary Mach lookup exception for that exact service.
This is a distribution prototype choice, not a claim that every App Group needs an exception.
Test whether group-based access suffices before removing the exception.
The installed diagnostic now verifies a request-scoped marker round trip through the
App Group container for both app/agent and extension/agent pairs. The signing team
and all identifiers are resolved by the CLT assembler into each Info.plist.

NSXPCListener applies a code requirement for the app/extension of the same team.
NSXPCConnection applies a code requirement for the agent. Missing or malformed signing
configuration must fail closed. No PID-only authentication. Protocol messages carry a
version and UUID and are size-limited before decoding. Future mutations require deduplication
and persistent recovery records; ping has no stateful side effect.

## Service lifecycle

The agent is embedded in `Contents/Library/Helpers`. Its launch plist is embedded in
`Contents/Library/LaunchAgents`; BundleProgram is relative to the containing application.
Registration is a user action via SMAppService. The prototype permits stopping/unregistering
from its diagnostic window. Installation paths and background approval affect behavior.
A signed build in a temporary build directory is not an installation test.

On update, stop accepting mutations, finish/checkpoint active operations, unregister the
old service and coordinate replacement/re-registration. Verify Finder's loaded extension
version. These are release acceptance gates, not implemented updater behavior.

## Permissions

No Automation or Accessibility is needed for diagnostic ping. Later Apple Event adapters
need the relevant hardened-runtime entitlement and usage description in the responsible
process. Ask for consent only at feature use. Unsandboxed processes still obey TCC and
filesystem permissions. Never treat a URL string as proof of access.

## Sources

- [Finder Sync](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html)
- [App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [XPC peer requirements](https://developer.apple.com/documentation/foundation/nsxpcconnection/setcodesigningrequirement(_:))

## Volume coverage

Register the root filesystem and each mounted volume explicitly. Monitoring only `/`
did not expose the menu on an external FAT32 USB volume during testing. Refresh the set
outside menu construction when workspace mount/unmount notifications arrive. Network
and cloud-provider behavior still needs separate checks.


## Implemented product services

`FinderSync` caches menu descriptors, preferences, installed applications and a Git root.
Its menu callback reads memory and captures selection; the agent performs file work after an
authenticated, bounded version 2 action request. Request IDs are reserved before side effects,
requests expire after five minutes and old receipts are pruned after two days. Retries never
silently repeat a file operation.

Preferences and templates use the resolved shared App Group. Settings save preferences
atomically and the helper refreshes the menu catalog asynchronously. Template expansion is
one pass, so replacement values cannot introduce recursively expanded tokens.

`MoveEngine` owns pure file/journal operations. `MoveActions` serializes UI-triggered batches,
selects conflict policies and runs disk work outside MainActor. Recovery intentionally keeps
verified copies. Settings display recent batches and reveal all their recovery locations.
See [ADR 0002](adr/0002-recovery-shortcuts-and-updates.md) for shortcuts and update decisions.
