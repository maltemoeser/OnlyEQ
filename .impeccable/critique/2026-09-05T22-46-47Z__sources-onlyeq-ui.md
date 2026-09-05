---
target: the app UI (Sources/OnlyEQ/UI)
total_score: 28
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 2
timestamp: 2026-09-05T22-46-47Z
slug: sources-onlyeq-ui
---
# OnlyEQ design critique — Sources/OnlyEQ/UI (2026-09-05)

Provenance: Assessment A (design review) and Assessment B (detector + screenshot evidence) ran as two isolated subagents. Native macOS app: the markup detector found nothing scannable (exit 0, zero rules), browser overlays skipped.

## Heuristic scores (28/40)

| # | Heuristic | Score |
|---|---|---|
| 1 | Visibility of system status | 4 |
| 2 | Match with real world | 3 |
| 3 | User control and freedom | 2 |
| 4 | Consistency and standards | 2 |
| 5 | Error prevention | 3 |
| 6 | Recognition over recall | 3 |
| 7 | Flexibility and efficiency | 2 |
| 8 | Aesthetic and minimalist design | 4 |
| 9 | Error recovery | 3 |
| 10 | Help and documentation | 2 |

Cognitive load: 5 of 8 checklist items fail (single focus, chunking, grouping, working-memory bridge, progressive disclosure). Editor toolbar shows 7 controls, bottom bar 6.

## Design specificity

Authored for an EQ: log-frequency curve with live input/output spectrum is the hero on every surface, band colours echo between nodes and cards, boost slider turns orange past unity. Only Settings is generic, which is correct on macOS.

## Priority issues

- [P1] No undo for band edits or deletes. Register undo in AppState mutations reached from EditorView; route Cmd-Z through AppShortcutMonitor.
- [P1] Q is text-only. Add scroll wheel or Option-drag on DraggableBandNode; show Q while dragging.
- [P2] Band strip clips band 6 with hidden scroll indicators (editor.png). Show indicators, scroll selected card into view via ScrollViewReader.
- [P2] Four toggle styles for peer controls (Bypass bordered button, Crossfeed switch in editor but button in popover, Auto checkbox, Settings native switch). Bypass state is not distinguishable from a plain button in screenshots. One style per surface; move Bypass to the editor bottom bar beside Crossfeed and Limiter.
- [P2] Accessibility: 4 of 6 icon-only buttons have no accessible name (Settings plus/minus, add band, delete band). All 76 fonts are fixed .system(size:), so nothing follows the system text size.
- [P3] Onboarding step 3: "Skip — start flat" and "Start Listening" call the same finish(apply: nil); list selection commits without confirmation.

## Minor

- Preset name truncates in the popover row ("HD 650 · oratory19…").
- Peak meter "-60.0 dBFS" text near-invisible; axis labels around 3:1 contrast.
- Capitalisation mixed Title Case / sentence case across Settings headers and buttons.
- Spacing uses 18 distinct values with no 4/8-pt scale.
- "Reset all settings…" + "Reset…" doubles the ellipsis. Popover gear menu lacks Cmd-, and Cmd-Q.
- Crossfeed appears in three places; unclear whether it is per preset or global.

## Questions

1. Should the master switch and Bypass become one three-state control (On / Bypass / Off)?
2. Would a single inspector for the selected band beat n small cards?
3. Are Crossfeed and Limiter preset properties or global?
