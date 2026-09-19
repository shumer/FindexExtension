# Detailed usage

[Back to the README](../README.md)

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
need runtime checks with those applications installed. See [verification](verification.md).

Finder extension activation and background helper registration are separate. Basic file
creation and path copying do not need Automation or Accessibility. Finder shortcuts and
scripted terminal adapters ask for Automation when used. Notification permission is optional;
errors remain visible when success notifications are disabled. Automatic rename is not used.
The notification request waits up to five minutes for the system prompt and uses a separate
connection so other settings remain available. If no result arrives, check Notifications in
System Settings; retrying file operations is not necessary.
