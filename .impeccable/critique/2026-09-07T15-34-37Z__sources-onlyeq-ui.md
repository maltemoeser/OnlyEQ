---
target: Sources/OnlyEQ/UI
total_score: 29
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 2
timestamp: 2026-09-07T15-34-37Z
slug: sources-onlyeq-ui
---
Method: dual-agent (A: critique-a · B: critique-b)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Peak meter reads in secondary colour and its dot has no label; "Applied automatically for this device" is hover-only. |
| 2 | Match System / Real World | 3 | Fc/Gain/Q right for the audience; onboarding tagline and "We'll import" break the plain first-person voice; "Larger = more stable". |
| 3 | User Control and Freedom | 3 | Editor undo is scoped well; A/B switch bypasses undo (AppState.swift:605-609); popover preset picks are not undoable and rewrite the device profile. |
| 4 | Consistency and Standards | 3 | One window called Editor / Equalizer / OnlyEQ; "Delete Band" (context menu) vs "Delete band" (a11y label); Title Case vs sentence case mixed. |
| 5 | Error Prevention | 3 | Clamping, Save-replace warning, disabled Apply are good; 32-band cap fails silently (EditorView.swift:286). |
| 6 | Recognition Rather Than Recall | 2 | Undo, Delete key, ⌘S exist but nothing on screen says so (no Edit menu); Q only by typing; A/B never shows slot state; band enable lives only in a context menu. |
| 7 | Flexibility and Efficiency | 3 | Scroll-wheel volume, double-click add, Delete, ⌘S, global hotkeys; no arrow-key nudge, no fine-drag modifier, no Q from the graph. |
| 8 | Aesthetic and Minimalist Design | 4 | Restrained; only the permanent "Double-click graph to add band" hint and the doubled drop-zone lines. |
| 9 | Error Recovery | 2 | Browse errors dump localizedDescription with no Retry (ImportSheet.swift:214); onboarding apply swallows fetch failure with try? (OnboardingView.swift:174); drop zone never highlights (isTargeted: nil). |
| 10 | Help and Documentation | 3 | Tooltips and Settings footers are good; no in-app list of editor keyboard commands. |
| **Total** | | **29/40** | **Good** |

## Design Specificity Verdict

**LLM assessment**: Authored where it counts. The editor and popover are unmistakably this product: input-versus-output spectrum under the accent curve, a band palette tying graph handle to card, Bypass and Crossfeed as paired listening toggles, the boost slider's 100 % tick and orange over-unity zone. Two surfaces are category-interchangeable: the onboarding welcome (rounded icon, big title, tagline, "Get Started") and the import Drop tab (dashed zone with a download glyph). Settings is deliberately generic, which the brief asks for.

**Deterministic scan**: `detect.mjs` exited 0 with an empty array because it walks only web extensions (html, css, jsx, tsx, js, ts, vue, svelte, astro) and never opened the nine Swift files. Manual scan of `Sources/OnlyEQ/UI/*.swift`: 3 fixed-point fonts (two deliberate hero icons at 34/40 pt, one computed CATextLayer size); 58 hard-coded frames, mostly window sizes, graph geometry, and decorative dots, but fixed value-column widths (SettingsView 64 pt, EditorView 52/28/78 pt) will clip under larger text; 0 unlabelled icon buttons; 2 of 3 `Toggle("")` without an accessibility label (SettingsView.swift:166 device auto-apply, :224 hotkey enable); 0 literal RGB/hex colours; 4 animations with no `accessibilityReduceMotion` check; 4 `.onTapGesture`, three with no keyboard path (curve card PopoverView.swift:184, BandCard EditorView.swift:239, onboarding row :131); copy uses "…" and curly quotes throughout; button titles mix Title Case and sentence case. Build: 0 warnings. Self-test: 185 passed, 0 failed. Browser steps skipped: native macOS app, no web target.

Where A and B agree: unnamed Settings switches, keyboard-unreachable band selection, no in-app shortcut discovery. Detector caught what A missed: no reduce-motion check, fixed value-column widths, the Title/sentence case clash. False positives: hero icon sizes, knob white/black fills, window frames.

## Overall Impression

The listening surface is right and the editing surface is now recoverable. What remains is invisibility: state that exists but is never shown (device binding, A/B slot contents, the 32-band cap, keyboard commands) and one structural flaw, band colour keyed to position. The single biggest opportunity is making band identity stable and reachable by keyboard.

## What's Working

1. **Honest visualisation.** Level-aligned input/output bars subtract static gain so only filter shape shows (EQCurveView.swift:266-269). A cut shows grey above accent, a boost the reverse.
2. **Undo scoping.** One step per drag, nothing registered for a no-op, action names set (EditorView.swift:163-175, AppState.swift:582-601).
3. **Bypass as the product thesis.** Level-matched, preset-preserving, and the popover's disabled state dims the cards to 45 % while Import, Editor, and Settings stay live.

## Priority Issues

- **[P1] Band colour is positional.** `BandPalette.color(index)` is used at EQCurveView.swift:195,448 and EditorView.swift:552,589. Delete band 2 and every later band changes colour on graph and card; undo then looks like it changed more than it did. Fix: a stable colour key per band (a `colorIndex` on `EQBand` assigned at creation, or derived from `band.id`). Command: /impeccable harden.
- **[P1] Keyboard and VoiceOver cannot reach the graph or select a band.** Nodes (EQCurveView.swift:447-476) are Circles with a drag gesture and no accessibility element. BandCard selection is `.onTapGesture` only (EditorView.swift:239), so the Delete key needs a mouse click first. Settings switches at SettingsView.swift:166 and :224 are `Toggle("")` with no name. Fix: `.focusable()` on BandCard driving `selectedBandID`; accessibility element per node with label "Band 3, Peak", value "118 Hz, −3.1 dB, Q 0.50", adjustable action for gain; arrow-key nudge on the selected node (⌥ fine); named toggles with `labelsHidden`. Command: /impeccable audit.
- **[P2] A/B has no visible state and bypasses undo.** `storeABAndSwitch` (AppState.swift:605-609) assigns `preset` directly; first switch to B silently copies A so both slots are identical. Fix: mark filled slots, route the switch through `recordingUndo("Switch A/B")`. Command: /impeccable harden.
- **[P2] Picking a preset in the popover silently rebinds the device.** `apply()` (AppState.swift:504-511) writes the profile on every non-auto apply; the only trace is a hover tooltip (PopoverView.swift:155). Fix: a visible caption under the preset name, "Auto for External Headphones". Command: /impeccable clarify.
- **[P2] Silent no-ops and mute failures.** 32-band cap returns without feedback (EditorView.swift:286); onboarding apply uses `try?` and shows nothing (OnboardingView.swift:174); Browse error has no Retry (ImportSheet.swift:214); drop zone passes `isTargeted: nil` (ImportSheet.swift:91); empty search shows a blank list. Fix: disable add at 32 with help "32 bands maximum"; error row with Retry; targeted border; "No results for …" row. Command: /impeccable harden.
- **[P3] Naming and copy.** One window named Editor / Equalizer / OnlyEQ; "Delete Band" vs "Delete band"; onboarding tagline off-voice; "Larger = more stable"; permanent double-click hint. Command: /impeccable clarify.

## Persona Red Flags

**Alex (power user):** no Q from the graph, no arrow-key nudge, no fine-drag modifier; A/B ambiguity; opt-in ⌘] and ⌘\ hotkeys collide with Safari and 1Password with no warning; Gain field shown for Low/High Pass and Notch where it does nothing (EditorView.swift:578).

**Sam (VoiceOver, keyboard):** graph nodes invisible to VoiceOver; cannot select a band by keyboard, so Delete is unreachable; unnamed switches in Devices and Shortcuts; popover curve card is a tap target with only a tooltip; onboarding (520×440) and import (560×470) frames do not grow with text size while the popover does.

**Riley (stress tester):** long preset names truncate to "HD 650 · oratory19…" beside two buttons; delete recolours later bands; 32nd band vanishes; 32 cards is a 5,000-point strip; a ±30 dB band flattens every other band with no zoom back.

**The maintainer with an HD 650:** well served by the popover. Two flags: the Bluetooth suggestion opens the editor with an import sheet on connect (AppDelegate.swift:26-28), the interruption "never think about it again" forbids; and hover-only "Applied automatically" means they cannot tell at a glance whether the visible preset is the bound one.

## Minor Observations

- Status dot stays green while Bypassed (PopoverView.swift:259-266).
- Preamp readout shows the effective value next to a disabled slider in Auto; reads as stuck. A "(auto)" suffix would fix it.
- "Choose File…" is a bordered button inside a dashed zone that is not itself a button.
- Frequency axis labels clamp 14 pt from the edges, so "20 Hz" and "16 kHz" sit off their gridlines at narrow widths.
- No `accessibilityReduceMotion` check on the four animations.
- Onboarding step 2 enables the EQ on appear; the copy should say "OnlyEQ is now asking for access".

## Questions to Consider

1. Should the band palette exist at all? A stable number badge on each handle ties handle to card without twelve hues, and DESIGN.md's one-hue rule would then be literally true.
2. Is A/B worth its toolbar slot for a user who edits twice a year? Level-matched Bypass plus undo and Revert may cover it.
3. If the popover is the whole product for the maintainer, why is the device binding the one piece of state on it with no visible representation?
