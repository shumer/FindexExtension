## New in 0.1.1

- Added Show/Hide Hidden Files to Finder context menus, the Finder toolbar menu and
  Menu settings. It sends Finder's native Command-Shift-Period shortcut without
  restarting Finder or changing its saved preferences.
- The command uses a neutral title without a checkmark because Finder's current
  visibility can differ from its saved preference.
- First use requires Accessibility access for FinderPackAgent in System Settings >
  Privacy & Security > Accessibility. Grant access and retry the command.

## Install or update

1. Download the universal DMG for Apple Silicon and Intel, requiring macOS 14 or later.
2. Open it and drag FinderPack to Applications. For an existing installation, use
   Check for Updates in FinderPack instead.
3. Launch FinderPack from Applications, enable its Finder extension and connect the
   background helper if this is your first installation.
4. Open a new Finder context menu and choose Show/Hide Hidden Files.

The application and disk image are Developer ID signed, notarized and stapled.
Release assets include the signed Sparkle update archive, checksums and build metadata.
Do not remove quarantine attributes or disable Gatekeeper.

Runtime verification covers Apple Silicon on macOS 26.6.2. Intel and other supported
macOS versions still require broader runtime acceptance.
