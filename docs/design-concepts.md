# Design concepts

Status: owner selected A, Direct, on 2026-09-19.
The approved direction is recorded in [DesignSpec](DesignSpec.md).
This document preserves the alternatives and the original recommendation.

## Comparison

| Proposal | Finder placement | Success feedback | Main tradeoff |
| --- | --- | --- | --- |
| A: Direct | Four action groups at the top level | System notification | Easy discovery, larger Finder menu; notifications require permission and may be suppressed. |
| B: Compact | One FinderPack item containing four groups | Silent | Minimal menu footprint, extra navigation for every command. |
| C: Hybrid | Copy Path at the top level, remaining choices in FinderPack | Brief HUD | Fast common action with modest menu footprint, less common formats remain nested. |

All proposals keep six settings sections: Menu, Templates, Applications, Shortcuts,
Feedback and About. The underlying actions and permission model are identical.
These are placement and feedback alternatives, not three separate products.

## Recommendation

Start with C. For a selected file, Copy Path immediately copies the absolute path.
For multiple files, Copy Paths copies one path per line. Other formats remain in
FinderPack > Copy Path. The folder background replaces the quick action with
New File; the submenu omits that duplicate group. Move To is absent without a
selection. The availability of Open In follows the target folder or selected files.

Keep success feedback short and allow users to silence it. Always show actionable
errors. Operations lasting longer than one second show progress and cancellation.
Undo belongs to the last eligible FinderPack move, with recovery rules enforced by
the agent. Neither the mockup nor a notification is proof that a move completed.

A remains useful for users prioritizing discoverability. B suits users who want
minimal additions to Finder. Menu placement should eventually be configurable,
but the first implementation should use one selected default consistently.

## Interactive comparison coverage

The conversation comparison includes:

- A, B and C menu placement, system/light/dark appearance and three selection scenes.
- Clickable action groups and path/template/application/destination choices.
- Six settings sections and an editable template content preview.
- Separate extension and background helper onboarding steps.
- Success, permission error, progress, cancellation and move undo examples.
- Three provisional icon directions, each paired with a monochrome toolbar symbol.

The comparison is illustrative. It does not access files, copy to the clipboard,
request permissions, install extensions or change application preferences.
Template import, ordering, shortcut recording and application discovery are only
represented; their actual interactions require production implementation.
The icons are studies using generic symbols, not release artwork.

## Proposed tokens

These are candidates for the later DesignSpec, not measured native UI acceptance.
Finder owns context menu font, row height, materials and submenu geometry.
The comparison cannot override or promise their exact native appearance.

| Element | Candidate |
| --- | --- |
| Application body | System font, 13 pt, regular. |
| Window heading | System font, 20 pt, medium. |
| Section heading | System font, 14 pt, medium. |
| Settings content inset | 24 pt desktop, 16 pt compact. |
| Layout spacing | 4 pt grid, primary gaps 8/12/16/24 pt. |
| Settings navigation | 180 pt candidate width; adapt for translated labels. |
| Window corner | System-managed in production; 12 pt in comparison. |
| Group corner | 10 pt. |
| Button corner | System-managed in production; 6 pt in comparison. |
| Template symbol | 16 pt. |
| App icon study | 88 pt preview, final artwork requires platform asset sizes. |
| Colors | labelColor, secondaryLabelColor, windowBackgroundColor, controlBackgroundColor, separatorColor and controlAccentColor. |
| Selection | System selected content colors, with text/state indicators. |
| Materials | Standard settings/sidebar materials; opaque fallback for Reduce Transparency. |
| Success HUD | 1.5 seconds, no focus stealing; duration configurable if required by accessibility review. |
| Motion | At most 120 ms for own transient feedback; none under Reduce Motion. |
| Progress | Show after one second; user-controlled dismissal for errors. |

Use native controls and platform appearance in implementation. Verify contrast,
VoiceOver, keyboard navigation, Increase Contrast, Reduce Motion, Reduce
Transparency and translation expansion in the running app. The comparison uses
opaque surfaces and does not attempt to reproduce glass rendering.

## Next step after selection

Record the chosen default and any changes in DesignSpec.md. Then implement Copy
Path and New File through the authenticated agent: validated requests, shared
preferences, atomic template storage, safe collision handling and visible errors.
Verify these actions in Finder before adding further action groups.
