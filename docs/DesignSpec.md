# FinderPack design specification

Status: owner selected proposal A, Direct, on 2026-09-19.

## Finder menu

Use four native top-level action groups: Copy Path, New File, Open In and Move To.
Only implemented actions are visible. Do not add a FinderPack root submenu.
Copy Path exposes named format choices. New File exposes the current template catalog;
a single available template can be a direct action. No default keyboard shortcuts.
The initial delivery implements path copying and regular text-file templates.

File selection supplies copy inputs. Container background supplies its folder when no
items are selected. New File uses the targeted folder, or the targeted file's parent.
Multiple selected files do not imply creating multiple files. Missing context disables
an action and must never fall back to the home directory or another guessed location.

Finder owns menu typography, spacing, submenu placement, contrast and material.
Use 16 pt system template symbols where Finder supports them. Use system fonts,
semantic colors and native controls throughout the app.

## Feedback

Successful actions use system notifications when authorized. Request notification
permission from an explicit control in the main app, never while constructing menus.
Denied notification permission does not prevent actions. Errors remain visible through
an alert. New File also reveals the created file. Never steal focus for copy success.
Long-running moves will show progress after one second with cancellation and recovery.

## Settings and onboarding

Six sections: Menu, Templates, Applications, Shortcuts, Feedback and About.
Use a 4 pt grid, 24 pt content inset, 12 pt row spacing and 16 pt template symbols.
Body text uses the system 13 pt font, section headings 14 pt medium and window content
headings 20 pt medium. Native control/window geometry takes precedence over mockup radii.
Settings navigation starts at 220 pt, with a 200 pt minimum and 280 pt maximum for localization.
Installed Russian testing showed truncation at 180 pt; the main window now starts at 900 pt.

Extension activation and background helper registration are separate setup steps.
Automation and Accessibility are requested only when the corresponding feature needs them.
The existing setup harness remains explicitly labeled during incremental delivery.

## Accessibility and appearance

Follow system light/dark appearance and accent color. Use semantic labels and native
keyboard navigation. Respect Reduce Motion and Reduce Transparency. Keep actionable
errors persistent. Product labels support English, Russian, Ukrainian and Polish.
Verify VoiceOver and translated layouts in the final settings UI.

## Delivery boundaries

Selection approves A's information architecture and feedback direction. Generic icon
studies are not final artwork. The settings mockup is not a completed implementation.
Template directories, custom metadata, author settings, shortcuts and moves remain
separate roadmap items until implemented and verified.
