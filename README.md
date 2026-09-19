# FinderPack

[![Checks](https://github.com/shumer/FindexExtension/actions/workflows/checks.yml/badge.svg)](https://github.com/shumer/FindexExtension/actions/workflows/checks.yml)

FinderPack adds native commands to Finder for copying paths, creating files from templates,
opening files in applications and moving files with recovery history.

macOS 14 or later. Release builds contain Apple Silicon and Intel binaries. Runtime testing
currently covers Apple Silicon on macOS 26.6.2; other supported systems still need acceptance
checks. The project is in development and no stable public release has been published.

## Features

- **Copy Path:** absolute path, shell quoting, file URL, browsing-folder relative, Git-root
  relative, home-relative, filename, filename without extension and parent folder.
  Multiple results can use newlines, spaces or commas. Git-relative output appears after
  the background cache discovers a repository.
- **New File:** text and directory templates, numbered collision handling, custom menu
  labels, symbols and ordering. Import files by dropping them into Templates or using Import.
- **Open In:** installed terminal and editor choices. Paths are passed as data, never as
  unescaped shell source. See the adapter verification notes below.
- **Move:** choose a destination, reuse five recent folders, cut, paste a copy, paste and move,
  or explicitly move copied files. Conflict choices include Keep Both, Skip and replacement
  with a retained backup. Ordinary paste never removes its source.
- **Recovery:** persisted move records, recent operations in Settings and conditional undo.
  Undo refuses to overwrite occupied paths or restore files changed after the operation.
- **Settings:** native Menu, Templates, Applications, Shortcuts, Feedback and About sections.
  English, Russian, Ukrainian and Polish product strings are included.
- **Shortcuts:** record combinations for copying a path and creating a file. No defaults.
  Finder-only registration is the default. Optional global shortcuts use the frontmost Finder window.

## Install

### From a signed release

When a release is available, download its DMG from [Releases](https://github.com/shumer/FindexExtension/releases).

1. Open the DMG and drag FinderPack into Applications.
2. Launch FinderPack from Applications, not from the disk image.
3. Use **Open Extension Settings** and enable the FinderPack extension in macOS.
4. Use **Connect** to register its background helper. Approve background operation if macOS asks.
5. Open a new Finder context menu. Settings changes appear in new menus within five seconds.

Release assets include SHA-256 checksums and `build-info.json`. Signed releases require both
application and DMG notarization. Do not remove quarantine attributes or disable Gatekeeper.
If macOS rejects an artifact, check its source and report the error.

### Build locally

Command Line Tools are sufficient; full Xcode and a generated Xcode project are not required.
Python 3, Ruby and the system signing tools must be available. Builds download the pinned
Sparkle archive and verify its SHA-256 digest before use.

```sh
xcode-select --install
git clone https://github.com/shumer/FindexExtension.git
cd FindexExtension
./run-tests.sh
./scripts/typecheck-app.sh
./build.sh --release --no-install
```

A Developer ID Application identity with its private key must already be available in your
Keychain. The build discovers it and derives the team identifier. To choose an identity,
set `CODESIGN_IDENTITY` to its certificate name or SHA-1. No signing keys belong in the repo.

Output: `build/FinderPack.app`. The release build assembles universal binaries, signs nested
components first and verifies the complete bundle. It does not install or publish anything.

Notarize with your existing Keychain profile:

```sh
./scripts/notarise.sh build/FinderPack.app FinderPack
```

Then copy the stapled app into Applications and follow the setup steps above. When replacing
an installed development build, disconnect its helper in About before replacing the app,
then reopen it and reconnect. Do not restart Finder automatically.

For compilation and artifact inspection without signing credentials:

```sh
CODESIGN_IDENTITY=- ./build.sh --no-install
```

This ad-hoc build is not a distributable installation and cannot use the authenticated agent.

## Templates

Templates live in the resolved App Group container under `Library/Application Support/Templates`.
Use **Templates > Reveal** to open that location. The app and helper share this single store.
Changes made outside the app refresh asynchronously.

The first launch seeds plain text, Markdown, PHP, JavaScript, TypeScript, JSON, shell,
`.gitignore` and `.env`. Deleted templates are not recreated. Templates can contain:

| Token | Value |
| --- | --- |
| `{{date}}` | UTC date, YYYY-MM-DD |
| `{{datetime}}` | ISO 8601 UTC timestamp |
| `{{filename}}` | Actual reserved filename, including a collision number |
| `{{author}}` | Configured author, or the macOS account display name |
| `{{year}}` | Four-digit UTC year |
| `{{uuid}}` | One UUID captured for the creation request |

UTF-8 and BOM-marked UTF-16 are supported. Binary content stays unchanged. Import preserves
placeholders rather than expanding them. Regular template files are limited to 1 MiB.
Directory templates are supported; symlinks inside them are rejected rather than followed.
New files use default permissions subject to umask, retain template execute bits and clear
inherited ACLs. Failed creation can leave a partial result; the error reports that possibility.

The editor detects external content changes before saving. Reload or save the current
text before switching templates with unsaved edits. Deletion moves a template to Trash.

## File operations and recovery

Same-volume moves use an exclusive rename. Cross-volume moves copy to staging, verify
content, permissions, modification times, extended attributes and ACLs, then keep the original
under a recovery name on its original volume. Symlinks move as links; packages remain one item.

Cross-volume filesystems that cannot preserve the verified metadata may reject a move. The
source is retained. Cancellation stops at safe steps; a copy already in progress may need to
finish before it can stop. A failed batch attempts to undo completed moves and retains its
journal if recovery cannot complete.

Recovery copies consume disk space. Recent operations offer Reveal and Undo Move. Retained
copies are not silently purged. Before removing an old recovery copy yourself, verify the
active file and any needed undo history. Undo is FinderPack's own operation, not Finder's
Command-Z history. Disconnected volumes or external edits can prevent automatic recovery.

Cut intent is bound to the clipboard change count and is lost when another app changes the
clipboard or the helper restarts. **Paste (Copy)** always copies. **Paste and Move** requires
valid FinderPack cut intent. **Move Copied Files Here** is a separate explicit move command.

## Applications, shortcuts and permissions

Application adapters cover Terminal, iTerm2, Ghostty, Warp, Alacritty, kitty, WezTerm, Hyper,
VS Code, Cursor, PhpStorm, WebStorm, Sublime Text, Zed and Neovim. Only detected choices appear.
Neovim is detected at the standard Homebrew executable locations. Editors receive selected
files; terminal actions use the selected directories or files' containing directories.
Multiple distinct folders produce separate terminal launches.

Third-party terminal adapters are implemented from their documented interfaces but still
need runtime checks with those applications installed. See [verification](docs/verification.md).

Finder extension activation and background helper registration are separate. Basic file
creation and path copying do not need Automation or Accessibility. Finder shortcuts and
scripted terminal adapters ask for Automation when used. Notification permission is optional;
errors remain visible when success notifications are disabled. Automatic rename is not used.
The notification request waits up to five minutes for the system prompt and uses a separate
connection so other settings remain available. If no result arrives, check Notifications in
System Settings; retrying file operations is not necessary.

## Updates and removal

Sparkle 2 is embedded for signed updates. An update-enabled build requires a matching EdDSA
public key and signed appcast. Until the release key and feed are configured, **Check for
Updates** explains that automatic updates are unavailable and links remain available in About.
An update unregisters the helper before installation and reconnects it after relaunch.
A real two-version update test remains a release gate.

To remove FinderPack, disconnect its helper in About, quit the app and move it from
Applications to Trash. Your templates and recovery files stay in the App Group container.
Review them before removing that container.

## CI and releases

[Checks](https://github.com/shumer/FindexExtension/actions/workflows/checks.yml) runs on pushes
to main and pull requests: source validation, core checks, strict Swift typechecking,
separate-volume recovery tests and an inspectable ad-hoc bundle.

[Signed release candidate](https://github.com/shumer/FindexExtension/actions/workflows/release.yml)
is manually dispatched on main with an existing `vX.Y.Z` tag. It verifies the tag against
VERSION and main history, enforces increasing build numbers, signs and notarizes the app,
creates a signed/notarized DMG and ZIP, signs the update archive, generates its appcast and
uploads immutable assets to a **draft** release. It never falls back to ad-hoc signing or
replaces published assets. Secrets are removed in an always-running cleanup step.

Configure the repository's `release` environment with these secrets:

- `DEVELOPER_ID_P12`: base64 certificate and private key.
- `DEVELOPER_ID_P12_PASSWORD`: exact P12 export password.
- `NOTARY_KEY_P8`: base64 App Store Connect API private key.
- `NOTARY_KEY_ID` and `NOTARY_ISSUER_ID`.
- `SPARKLE_PRIVATE_KEY`: Sparkle EdDSA private key in its exported base64 format.

Set repository variable `SPARKLE_PUBLIC_KEY` to the matching public key. The workflow checks
that the update keys match before importing the release certificate. See [release setup](docs/release.md)
for key handling, publication order and recovery. This repository currently has no signing
secrets configured; a signed GitHub release cannot run until they are supplied.

## Development documents

- [Selected design](docs/DesignSpec.md)
- [Product specification](docs/Specification.md)
- [Architecture](docs/architecture.md)
- [Verification and limitations](docs/verification.md)
- [Roadmap](docs/roadmap.md)
- [Repository rules](CLAUDE.md)

Before a commit, run `./run-tests.sh` and `./scripts/check-source.sh`. For application changes,
also run `./build.sh`. Use `./scripts/check-cross-volume.sh` for the separate-volume fixture.
Do not equate compilation or notarization with UI, update or compatibility acceptance.
