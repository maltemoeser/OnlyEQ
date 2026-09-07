---
target: popover and equalizer window
total_score: 28
max_score: 40
na_heuristics: 
p0_count: 1
p1_count: 3
timestamp: 2026-09-07T23-31-33Z
slug: sources-onlyeq-ui
---
Method: dual-agent (A: critique-a-4 · B: critique-b-4)

#### Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Fader readout sat above the track, so knob position and number disagreed; the "Error" pill names no cause |
| 2 | Match System / Real World | 3 | "Crossfeed" is explained only in a tooltip |
| 3 | User Control and Freedom | 3 | No undo for preset or device switches made from the popover |
| 4 | Consistency and Standards | 2 | Same sliders glyph on the preset row and Open Equalizer…; bypass drawn three ways; Bypass as the toolbar's principal item |
| 5 | Error Prevention | 3 | Per-card delete is one click with only undo behind it |
| 6 | Recognition Rather Than Recall | 3 | "(edited)" and "level-matched" on Compare slots must be recalled from tooltips |
| 7 | Flexibility and Efficiency | 3 | No Bypass keyboard shortcut in either surface |
| 8 | Aesthetic and Minimalist Design | 3 | Editor stacks toolbar, compare row, divider, then the graph; bottom bar of five unrelated controls |
| 9 | Error Recovery | 3 | Permission notice is good; "Error" pill offers no remedy |
| 10 | Help and Documentation | 2 | Everything lives in tooltips; no first-run teaching in the editor |
| **Total** | | **28/40** | **Good** |

#### Design Specificity Verdict

**LLM assessment**: The popover is authored for this product: the plot well with the live spectrum, the fader at its side, the capsule row under the axis, and the "Use automatically on <device>" line are decisions no template makes. The editor is the category layout (graph, card strip, preamp bar) under system chrome; its one authored idea, level-matched Compare, is undersold as a caption row between toolbar and graph.

**Deterministic scan**: `detect.mjs --json Sources/OnlyEQ/UI` exits 0 with `[]`, but the detector scans only web file types and read zero Swift files, so the result is not applicable rather than a pass. Mechanical greps found: `plus.circle` labelling both "32 bands maximum" and "Double-click to add band" (EditorView.swift:282, 285); bypass rendered as `waveform.slash`, plain text, and `eye.slash`; sixteen distinct padding and spacing values across the two main views; every icon-only control carries an accessibility label except the band value field while editing (EditorView.swift:779).

**Visual overlays**: skipped; native macOS SwiftUI surface with no URL.

#### Overall Impression

The popover is the product's peak and holds up: the spectrum breathes under the curve and Bypass settles the line flat. The valley is the hand-off to the editor, which greets the eye with chrome before the curve. The single biggest opportunity is making the editor's first read the curve, with Compare promoted into the toolbar rather than wedged under it.

#### What's Working

- The plot well and its spectrum are a signature: one surface, one hue, and a bypass animation that explains the feature better than copy.
- The preset row's "Use automatically on <device>" checkbox teaches the binding model in one line.
- Undo discipline in the editor: one undo step per drag and a named action for every edit.

#### Priority Issues

- **[P0] Fader readout and range**: the readout sat above the track, so the track was 16 pt shorter than the well and the knob never reached the plot's top line. Fix: track spans the well, readout on the axis line. Fixed this round. The reviewer also argued 100 % should be the track's top with boost reached past it; left as is, since the boost zone is a deliberate product feature.
- **[P1] Symbol semantics**: `slider.horizontal.3` on both the preset row and Open Equalizer…. Fix: preset row gets `waveform.path`, Open Equalizer… is text-only. Fixed this round.
- **[P1] Editor top region**: compare row sat tight under the unified toolbar. Fix: 8 pt above and below. Fixed this round; moving Compare into the toolbar remains open.
- **[P1] Toolbar ordering and Revert**: the reviewer advised keeping Revert as text because `arrow.uturn.backward` means Undo. Resolved with `arrow.counterclockwise`, the restore glyph, icon-only. Bypass gained ⌘B. Regrouping the toolbar remains open.
- **[P2] Bottom bar and band strip density**: bands were in file order. Fix this round: cards ordered low to high in frequency, order frozen during a drag. The bottom-bar regrouping and hover-only field fills remain open.
- **[P2] Device as a third capsule**: the reviewer advised against it; the user chose it. Shipped as a text capsule pull-down at the row's trailing end, Bypass and Crossfeed text-only so the name fits.

#### Persona Red Flags

**Alex (Power User)**: no Bypass shortcut (fixed: ⌘B in the editor); A/B switching is unnamed outside a tooltip; band fields need a click to edit; no numeric entry for the fader.

**Jordan (First-Timer)**: "Crossfeed" undefined outside its tooltip; the editor opens with no explanation of Compare or of the dashed per-band curves; the "Error" pill names no cause.

**Sam (VoiceOver/keyboard)**: the fader had a label and value but no adjustable action (fixed: 5 % steps); the band value field lacked a label while editing (fixed); the empty Compare slot's concatenated label reads as "circle B Choose…"; the band-card delete glyph is tertiary and low-contrast.

#### Minor Observations

- Editor axis labels drop the unit until 1 kHz; the popover keeps units. Pick one.
- The popover plot has no 0 dB label; one would help the bypass animation land.
- The "Bypassed" pill dot is secondary over a well dimmed to 55 %.
- The popover curve is a plain button with no hover affordance.
- Band cards use standard 8 pt corners while the wells use continuous corners.
- Padding and spacing use sixteen distinct values across the two main views.

#### Questions to Consider

- If the popover is the product and editing happens elsewhere, why does the editor open with chrome instead of the curve at full bleed under a transparent toolbar?
- Would the fader lose anything if 100 % were the top of the track and boost were reached only by scroll-wheel past the end?
- What would the editor look like if A/B were the toolbar's principal item, so the window's identity is "these two curves" rather than "this preset"?
