---
target: the editor window
total_score: 27
max_score: 40
na_heuristics: 
p0_count: 1
p1_count: 3
timestamp: 2026-09-08T17-08-56Z
slug: sources-onlyeq-ui-editorview-swift
---
Method: dual-agent (A: design review sub-agent · B: detector sub-agent)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 2 | In Bands mode with a non-neutral Adjust layer the curve misses its own handles and nothing says why |
| 2 | Match System / Real World | 3 | "Output" names both the spectrum legend and the peak meter; "Q" is bare |
| 3 | User Control and Freedom | 3 | Undo is named and per-drag, but only Cmd+Z reaches it; Escape does not cancel the Save sheet |
| 4 | Consistency and Standards | 3 | No checkmark on the current preset in the menu; hyphen-minus in fields, true minus on the axis |
| 5 | Error Prevention | 3 | A value field left by Tab keeps an uncommitted draft open |
| 6 | Recognition Rather Than Recall | 2 | Double-click, arrow nudge, Option fine steps, Delete key, meter reset all unhinted |
| 7 | Flexibility and Efficiency | 3 | Q cannot be changed on the graph; no shortcut for A/B or Bands/Adjust |
| 8 | Aesthetic and Minimalist Design | 3 | Adjust pane leaves the right half of the strip empty; idle meter text is noise |
| 9 | Error Recovery | 3 | Typing "abc" into a field is discarded silently |
| 10 | Help and Documentation | 2 | No tooltips on value fields, the type menu, or Auto |
| **Total** | | **27/40** | **Good, with gaps in status and discoverability** |

## Design Specificity Verdict

**Review:** Three elements are authored for this product and nothing else could ship them: the Compare row whose pills name the curve they hold and switch level-matched, the Adjust pane laying Bass/Treble/Tilt/Strength over a measured profile without touching it, and the input-versus-output spectrum behind the curve. The band list that mirrors the graph (frequency order, columns, order frozen during a drag) is quiet but distinctive. Bands mode itself is category-generic: node graph, Hz/dB/Q fields, X delete, preamp slider. A generic parametric EQ could ship Bands mode unchanged.

**Deterministic scan:** The detector ran on the editor file and the UI directory, both exit 0 with zero findings, but the tool has rules only for HTML, CSS, and JSX-shaped source. It scanned no Swift file with a matching rule, so the empty result is not evidence of a clean UI. The native audit reference covers iOS and Android only; its manual checks (accessibility labels and focus order, contrast, semantic colours, platform conformance) were folded into the review above.

**Visual overlays:** not applicable. The target is a native macOS window with no URL, so no browser injection was attempted.

## Overall Impression

The editor is honest and restrained, and the parts that carry the product's idea (Compare, Adjust, the spectrum) are good. The biggest opportunity is the seam between the two editing modes: Adjust is invisible from Bands mode, and a person who used it once and comes back to Bands sees a curve that no longer passes through its own nodes.

## What's Working

- **Compare pills** name what they hold, mark the edited one, and switch level-matched, so the mechanism is legible without a manual and honest about loudness bias.
- **The band list mirrors the graph.** Frequency order, column fill, and the order held still for the length of a drag mean rows never shuffle under the pointer. Handle numbers match row numbers for VoiceOver too.
- **Undo granularity is right.** One step per drag or slider drag, named actions, keyboard steps as their own steps, and typed drafts carry the exact unitless value so "1.5 kHz" does not become 1.5 Hz.

## Priority Issues

- **[P0] The curve and its handles disagree when Adjust is non-neutral in Bands mode.** The graph draws the rendered bands, the handles sit on the raw bands, and nothing explains the gap. Fix: when the adjustment is not neutral, show a caption in the graph's top-trailing slot ("Adjusted: Bass +2.0 dB, Tilt −1.0 dB"), draw the unadjusted composite as a 1 pt dashed secondary line, and mark the Adjust segment. Command: /impeccable polish.
- **[P1] Undo is invisible.** OnlyEQ is a menu-bar app with no main menu, so Cmd+Z is the only route and Redo is unguessable. Fix: add an undo affordance the window owns (Undo and Redo in the gear menu with their action names, and "Undoable" in the delete tooltips). Command: /impeccable clarify.
- **[P1] Q is unexplained and cannot be changed on the graph.** Fix: Option-drag or scroll on the selected handle changes Q with the dashed individual response as live feedback; give the Q field a tooltip ("Width. Higher is narrower.") and the type menu one per filter. Command: /impeccable shape.
- **[P1] The Save sheet is under-specified.** Escape does not cancel (Cancel lacks the cancel action), no text says what is saved, and the name-collision rule appears only when it triggers. Fix: bind Cancel to the cancel action, add a one-line caption ("Saves the bands, preamp, and adjustments as a preset."), prefill and select the current name. Command: /impeccable harden.
- **[P2] The peak meter hides its reset and never says "clipped".** It is a static text with an undocumented click. Fix: make it a button with an accessibility action and print "Clipped" in red when the held peak exceeds −0.1 dBFS. Command: /impeccable polish.

## Cognitive Load

Failures: 3 of 8 (chunking, minimal choices, working memory). Decision points with more than four visible options: the preset menu, the seven-item filter-type menu, the band grid, and the Compare "Choose…" menu. Working memory: Bands mode requires remembering whether Adjust is non-neutral, and shortcuts must be remembered from tooltips.

## Emotional Journey

Peak: dragging a handle while the curve, its dashed individual response, and the output spectrum move together. End: the Save sheet is bare and nothing confirms afterwards. Valleys: first open with an imported profile shows ten bands, a negative preamp, and an empty "B Choose…" slot with no framing that this is the published correction and Adjust is where taste goes. Deleting a band feels irreversible because nothing advertises undo.

## Persona Red Flags

- **Alex (keyboard power user):** Tab crosses six stops per band row before the next row. No key changes Q. No shortcut switches A/B or Bands/Adjust, no Cmd+N for Add Band. Option fine steps live only in a code comment.
- **Jordan (first-timer with an imported profile):** lands in Bands mode facing ten rows, "Q 0.70" and "Low Shelf" with no tooltips, and a preamp of −6.0 dB with no reason given. "B Choose…" reads as an unfinished form field. The pane built for them is behind a toolbar segment.
- **Sam (VoiceOver / keyboard-only):** band rows are focusable but unlabeled groups (a bare "1", then "Peak", then fields). The selected row's fill has no accessibility trait. The peak meter has no reset action. A value field left by Tab traps its draft.

## Minor Observations

- PRODUCT.md line 40 says band edits have no undo; the code has it.
- The preset menu label never shows an edited marker; only the A pill does.
- Hyphen-minus in field values, true minus on the axis.
- "Output" appears twice with two meanings.
- The Auto tooltip is on the number, not the checkbox.
- Reset in the Adjust pane would read better aligned with the readouts' bottom row.
- The window title is hidden, so Mission Control shows an unnamed window.

## Questions to Consider

- Should an imported preset open in Adjust with the bands read-only behind an explicit "Edit bands", so the primary path never shows a Q field?
- Since slot A is always the toolbar's preset, could Compare collapse into the toolbar and free a whole row?
- Could Q live on the graph as the width of the dashed response, dragged at its shoulders, so the Q field disappears?
- Is the preamp a user decision at all when Auto exists? One line, editable on click, slider only when Auto is off.
- The editor half-borrows the document idiom. Should it commit: proxy dot for edited state, Cmd+S saves in place, Save As… for a new name, unsaved-changes sheet on close?
