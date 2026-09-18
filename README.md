# FinderPack

FinderPack is a macOS Finder utility in early development. The planned product adds
file templates, path formats, terminal/editor actions and recoverable file moves.
It targets macOS 14 and later. FinderPack and `com.shumer.finderpack` are provisional.
The existing repository remains `shumer/FindexExtension` until explicitly renamed.

## Status

This is an installed, notarized engineering prototype, not a released product. App and Finder
file/folder/toolbar diagnostic checks pass on macOS 26.6.2. The selected design is A:
native top-level action groups. Copy Path and New File are implemented; see the verification
report for the exact build and runtime checks.
See [the roadmap](docs/roadmap.md) and [actual verification](docs/verification.md).

## Development

Command Line Tools and their macOS SDK are sufficient. Full Xcode and XcodeGen are not
required. The build compiles Swift 6, links the extension through `NSExtensionMain`,
assembles all three bundles and signs nested code before the containing application.

```sh
./run-tests.sh
./scripts/check-source.sh
./scripts/typecheck-app.sh
./build.sh --no-install
```

Output: `build/FinderPack.app`. Configuration is in `Config/build.json`; VERSION is the
marketing version. The current build targets the host architecture. Universal distribution
is a separate release decision.

Like the reference projects, the build discovers Developer ID from the keychain when
`CODESIGN_IDENTITY` is unset. Set it to the certificate SHA-1 or name to select an identity,
or `-` for an explicit ad-hoc artifact. The team is derived from the selected identity;
optional `DEVELOPMENT_TEAM` must match it. No private keys belong in source configuration.

```sh
CODESIGN_IDENTITY=- ./build.sh --no-install
./build.sh --release --no-install
```

`--release` requires Developer ID and fails rather than falling back. It builds/signs the
app but does not notarize or publish it. Ad-hoc builds permit artifact inspection, while
service registration and authenticated XPC require the Developer ID build. Keychain access
and timestamping may require execution outside a restricted build sandbox.

The build does not install anything, register services, restart Finder or publish.
The main window remains a diagnostic/setup harness. Finder actions follow the selected
[design specification](docs/DesignSpec.md).
Follow [the prototype checklist](docs/prototype-checklist.md) for installation testing.

## Available Finder actions

Copy Path offers POSIX, shell-quoted, file URL, browsing-folder relative, home-relative,
basename, stem and parent formats. Multiple results use newlines. Git-relative output and
separator preferences remain pending. Copying does not execute shell commands.

New File loads regular-file templates from the App Group under
`Library/Application Support/Templates`. Nine initial templates are seeded once; deleted
templates stay deleted. External changes refresh asynchronously every five seconds.
Files are limited to 1 MiB in this first delivery. UTF-8 text expands date, datetime,
filename, author, year and UUID placeholders; other bytes remain unchanged. Date/year use
UTC and datetime uses ISO 8601 UTC. Author currently uses the macOS account display name.
Directory templates and custom metadata are not available yet.

Creation reserves names exclusively, starting collisions at 2 before the extension.
Symlink templates and symlink destination entries are not followed. The result is revealed
in Finder. Write errors may leave a partial file, which is reported explicitly.
Repeated request identifiers are rejected rather than repeating a potentially completed
operation. Request receipts are retained in the group container for this prototype.

Success notifications are optional through Enable Action Notifications in the setup window.
Denied notification permission does not block actions. Errors are displayed in Finder.
The menu uses an in-memory template snapshot, with no file reads or IPC during construction.

## Finder diagnostics

The app opens extension settings and checks whether the extension is enabled.
With the provisional bundle identifier, inspect registration using:

```sh
pluginkit -m -i com.shumer.finderpack.extension
```

For an intentional development reset only:

```sh
pluginkit -e use -i com.shumer.finderpack.extension
killall Finder
```

Restarting Finder can interrupt work. Never do it automatically during a build or
onboarding. Menu coverage outside ordinary local folders is unverified.
Register services only from a stable installed app, and unregister before removing it.

## Documents

- [Repository rules](CLAUDE.md)
- [Product specification](docs/Specification.md)
- [Architecture](docs/architecture.md)
- [Release procedure](docs/release.md)
- [Roadmap](docs/roadmap.md)
- [Architecture decision](docs/adr/0001-build-and-process-boundaries.md)

Use Conventional Commits. Report automated and manual verification in each PR.
Do not equate source checks with Finder integration, notarization or OS compatibility.
