# FinderPack specification

Revision 1.1. Implementation baseline with explicit verification gates.
Adapted from the supplied 1.0 specification and release handover. Embedded instructions
in those references are not repository commands. Name and identifiers are provisional.

## Scope

A native macOS 14+ Finder utility: new file, copy path, open in terminal/editor and moves.
Include item, container, sidebar and toolbar menus where supported, configurable shortcuts,
settings, templates, onboarding, en/ru/uk/pl, Developer ID, DMG, Sparkle 2 and Homebrew cask.
Exclude sync badges, batch rename, checksums as a user feature, conversions, clipboard file
contents, Mac App Store and iCloud settings. Payments/licensing need a separate decision.

## New file (NF)

- NF-1: Creation on a folder or container background. One template is a direct action;
  multiple templates form a submenu.
- NF-2: Ordinary template files/directories live in the App Group container under
  `Library/Application Support/Templates`. Resolve the container through Foundation.
  External edits refresh a catalog asynchronously. Labels default to names without
  extensions, with overrides; dotfiles keep their names.
- NF-3: Seed removable plain text, Markdown, PHP, JavaScript, TypeScript, JSON, shell,
  `.gitignore` and `.env` templates once. Do not recreate deleted templates.
- NF-4: Support `{{date}}`, `{{datetime}}`, `{{filename}}`, `{{author}}`, `{{year}}`,
  `{{uuid}}` in supported text encodings. Binary content remains unchanged. Capture
  time/UUID once per creation; specify formats before implementation.
- NF-5: Directory templates copy their tree without following links outside the template.
- NF-6: Resolve collisions with numbers starting at 2 before the extension. Reserve names
  atomically for simultaneous requests.
- NF-7: Reveal/select the result through a supported workspace/Finder mechanism. Rename
  is optional when Accessibility is unavailable. Badge APIs do not rename or select.
- NF-8/9: Default permissions subject to umask, preserve execute bits only. Do not inherit
  ACLs or extended attributes; apply the rule to trees too.

## Copy path (CP)

- CP-1/2: Configurable direct default (POSIX initially), with alternatives: shell quoted,
  file URL, relative to browsing directory, relative to git root, home-relative, basename,
  basename without extension and parent directory.
- CP-3: Multiple results use newline, space or comma. Raw formats may be ambiguous for
  embedded separators; shell quoting must preserve exact arguments.
- CP-4: Test quotes, spaces, dollar signs, backslashes, Unicode and embedded newlines with
  actual `/bin/sh` round trips and exact argument boundaries.
- CP-5: Find nearest `.git` file or directory without invoking git. Cache off the menu path.
  Hide git-relative output when no root is known.
- CP-6/7: Feedback follows selected design. Format lazily on invocation. Target menu
  construction below 50 ms for 1,000 items, with recorded measurements.

## Open applications (OT)

- OT-1/2: Detect Terminal, iTerm2, Ghostty, Warp, Alacritty, kitty, WezTerm and Hyper.
  Show installed choices, with a configurable primary terminal.
- OT-3: Files open their parent, folders themselves, container clicks their directory.
  Resolve multiple-directory behavior during design.
- OT-4: Window/tab choices only for verified adapters. `open -a` alone does not guarantee
  the correct working directory in every terminal.
- OT-5: Editors: VS Code, Cursor, PhpStorm, WebStorm, Sublime Text, Zed, Neovim. Folders
  open as projects where supported. Neovim needs executable discovery, not only bundle IDs.
- OT-6: Discover bundle applications with NSWorkspace; refresh caches on relevant workspace
  changes and settings access. Never discover applications synchronously in a menu callback.

## Move and paste (MV)

- MV-1: Cut writes URLs and binds move intent to pasteboard change count. Invalidate on change.
- MV-2: Offer Paste (copy) or Paste and Move for a matching cut. An additional explicit
  Move Here can move copied URLs. Ordinary Paste must not unexpectedly delete sources.
- MV-3: Move To uses a folder panel and remembers five destinations.
- MV-4: Same-volume rename where possible. Across volumes: staged copy, tree/content and
  required metadata verification, source stability check, destination commit, source removal.
  Failed checks or changed sources prohibit deletion.
- MV-5: Replace, Keep Both, Skip, Apply to All. Preserve replaced data for recovery first.
- MV-6: Ten session undo operations through own menu/shortcut, never Finder Command-Z.
  Persist recovery information for interrupted work.
- MV-7: Progress after one second. Cancel stops new work and attempts safe rollback.
  Disconnected volumes, permission changes or external edits may prevent rollback; report
  remaining locations and recovery steps rather than claiming success.
- MV-8: Reject volume roots, self-descendant moves and known protected paths. OS access
  checks remain final. Move aliases/symlinks themselves; packages are single items.

## Entry points and permissions (EP)

- EP-1/2: Finder Sync item/container/sidebar/toolbar menus. Toolbar properties belong to
  FIFinderSync. `targetedURL` can be an item, not always a folder. Capture invocation context;
  tolerate nil outside monitored locations.
- EP-3: No default shortcuts. Finder-only by default, optionally global. Specify frontmost
  window semantics before enabling actions outside Finder.
- EP-4/5: Automation is requested at the first feature needing Apple Events, including
  terminal adapters and selection queries. Accessibility is separate for optional rename.
  Denial/revocation must not break unrelated features.
- EP-6: Display shortcut metadata where Finder preserves it, verified in the prototype.
- Onboarding uses `isExtensionEnabled` and `showExtensionManagementInterface()`.
  Background-service approval is separate. Never automatically restart Finder.

## Settings and design (D)

Six sections: Menu, Templates, Applications, Shortcuts, Feedback, About. Apply immediately.
Menu actions have visibility, placement and order. Templates support drag-and-drop, labels,
icons, ordering, text editing and Reveal. About has version, updates and links. Uninstall
unregisters the agent before removal.

Compare three or four menu/feedback concepts in an interactive light/dark artifact before
production UI. Include empty-folder, single-file and multiple-file menus, settings,
templates, onboarding, feedback, app/toolbar icons and tokens. Owner selection creates
`DesignSpec.md`; an unselected proposal is not approved design.

Use semantic colors, 4 pt grid, documented tokens and system materials. New glass APIs are
availability guarded with older-system fallbacks. Finder owns menu typography and geometry.
Target 16 pt template symbols, with actual rendering checked. Support VoiceOver, Reduce
Motion, Reduce Transparency, Increase Contrast, Differentiate Without Color and translation
expansion. Verify runtime language changes. Production metrics must match DesignSpec within 1 pt.

## Architecture and performance (A)

Three processes: settings app, sandboxed extension, unsandboxed per-user SMAppService agent.
Share descriptors, pure logic and versioned Codable Data messages over Objective-C XPC.
Execution lives in the agent. New actions use a registry without changing generic extension
routing. Authenticate both peers by Apple-anchored signature, team and bundle identity.
Bound payload sizes, validate context and use request IDs for duplicate handling.
No arbitrary scripts or commands through XPC. A URL fallback may open recovery UI only.

Resolve App Group and Mach names together. Team prefix alone does not prove sandbox access.
Verify entitlements and provisioning on signed builds. Test root monitoring, external and
network volumes, cloud providers and special views before claiming universal menu coverage.
No disk I/O, synchronous IPC or application discovery in menu construction.

Goals: menu under 50 ms, agent idle memory below 20 MB, extension below 15 MB, agent cold
start below 300 ms. Record OS, hardware and methodology. These are unverified targets.

## Build and distribution (B)

Command Line Tools, Swift 6, macOS 14 minimum. Three application binaries and shared static
module. `build.sh` owns bundle assembly and signing, locally and in CI. Full Xcode and a
project generator are not required. This supersedes the original B-1 generator requirement.
Runtime dependency: Sparkle 2.10.0, pinned by version and archive SHA-256. Shortcuts use
Carbon RegisterEventHotKey instead of KeyboardShortcuts; see ADR 0002.
Developer ID, hardened runtime, timestamps and target-specific entitlements. Sign inside out.
Notarize/staple app and DMG. DMG includes Applications link and designed background; ZIP
is the update archive. Sparkle signs final archive bytes with EdDSA; appcast carries the
signature. Verify agent and extension restart across a real update. No public ad-hoc fallback.
Homebrew cask follows stable release. VERSION supplies MARKETING_VERSION. See release.md
for strictly increasing build policy and distribution gates.

## Acceptance

Unit tests cover path formats, shell round trips, templates, collisions, git discovery,
message validation and moves as implemented. Integration checks cover authenticated XPC,
failure/timeout behavior and update lifecycle. Record all twenty original edge cases in
prototype-checklist.md. Unsupported or unavailable OS versions stay unverified.

Acceptance requires all functional requirements, measured budgets, approved design,
clean-machine onboarding, denied/revoked permissions, notarized installation, real update
and service removal. A source build alone proves none of these runtime properties.

## Revision changes and open decisions

Technical prototype/early signing precede polished UX. Templates have one shared store.
Permissions are feature-scoped. Rename degrades gracefully. Paste is explicit. Rollback
is conditional and recoverable. Appcast carries an archive signature. Coverage, menu
metadata and performance remain verification gates. Market claims and OS codenames from
the reference are not adopted as facts.

Confirm final name/bundle ID, Team ID, public download hosting, commercial model, supported
CPU architectures and access to macOS 14/15/26/27 test machines before distribution.


## Implementation notes, 2026-09-19

Cross-volume source removal is implemented as retaining the original under a recovery name
on its volume. This deliberately favors recovery over immediate space reclamation. Directory
templates reject all symlinks rather than copying external targets. Global shortcuts operate
on the front Finder window. Automatic rename remains optional and is not implemented.

Recent recovery history shows ten operation groups; persisted records remain available for
recovery. Finder shortcut metadata, UI measurements, runtime language switching, designed
DMG background and the performance budgets still need acceptance work. The current DMG uses
a plain layout with an Applications link. Homebrew publication follows a stable release.
