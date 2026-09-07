---
target: Sources/OnlyEQ/UI
total_score: 25
max_score: 40
na_heuristics: 
p0_count: 2
p1_count: 2
timestamp: 2026-09-07T13-10-18Z
slug: sources-onlyeq-ui
---
Method: dual-agent (A: critique-A-2 · B: critique-B-2)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | "Bypassed" and "Inactive" both mean "not processing" with no hint why two states exist (PopoverView.swift:267-277) |
| 2 | Match System / Real World | 3 | Crossfeed presets named after people, "Chu Moy (700 Hz, −6 dB)" (Crossfeed.swift:33-36) |
| 3 | User Control and Freedom | 1 | No undo; band delete, preset delete instant and unconfirmed (EditorView.swift:487-494, PopoverView.swift:135-139) |
| 4 | Consistency and Standards | 2 | Four toggle styles across three surfaces; "Preset" names two different things (SettingsView.swift:269) |
| 5 | Error Prevention | 2 | Save sheet pre-fills the current name so Enter overwrites silently (EditorView.swift:289); gain clamps at ±12 dB (EditorView.swift:496) |
| 6 | Recognition Rather Than Recall | 2 | Nothing on screen says which spectrum is input and which is output (EQCurveView.swift:258-261) |
| 7 | Flexibility and Efficiency | 3 | ⌘S and ⌘, exist; no keyboard nudge, no scroll-to-adjust Q, no fine-drag modifier |
| 8 | Aesthetic and Minimalist Design | 4 | Popover is four cards and a footer, as the contract promises |
| 9 | Error Recovery | 2 | Paste tab flashes raw localizedDescription errors mid-typing on a 250 ms debounce (ImportSheet.swift:157-170) |
| 10 | Help and Documentation | 3 | Tooltips on toolbar items; none on graph, spectrum, or A/B semantics (EditorView.swift:97) |
| **Total** | | **25/40** | **Acceptable** |

## Design Specificity Verdict

**LLM assessment.** Authored. The sameness is with macOS, which is what DESIGN.md asks for. Three things could belong to no other product: the curve editor whose per-band dashed responses share a colour with the band-card strip (EQCurveView.swift:175-210, EditorView.swift:466); the boost slider turning orange past unity (PopoverView.swift:317); and the grey input spectrum behind the accent output spectrum, with the baseline shifting by the bypass match gain (EQCurveView.swift:359). The popover layout itself is category-typical, but it is the surface least in need of distinctiveness.

**Deterministic scan.** Swift is not a scannable extension for the detector, so it exited 0 with an empty result rather than reporting unsupported input. A manual grep of the nine UI files stands in for it:

| Signal | Count |
|---|---|
| Fixed point sizes (`.font(.system(size:`) | 72 |
| `.accessibilityLabel` / `.accessibilityValue` | 1 / 1 (both on the volume slider, PopoverView.swift:305-306) |
| `.help` tooltips | 9 |
| Icon-only buttons with no name or tooltip | 4 (SettingsView.swift:120, 126; EditorView.swift:206, 487) |
| Distinct `.toggleStyle` values | 4 (`.switch`, `.button`, `.checkbox`, `AccentSwitchStyle` in two widths) |
| `.keyboardShortcut` | 6 |
| `.focusable` / `.focused` | 0 |
| Hard-coded colours (`Color(red:`, `Color(white:`) | 0 |

The detector and the review agree on the two structural findings: accessibility is near zero, and toggle grammar drifts across surfaces. False positives in the grep: 25 `.opacity(` hits include state-driven fades; 38 fixed frames include icon boxes; the two `Color(nsColor:)` uses are semantic system colours, not hard-coding.

**Visual overlays.** Not applicable; native app, no page to inject into.

## Overall Impression

The daily surface is finished. The popover does one job, never resizes, and the honest-sound principle is visible in the pixels through the level-matched bypass and the gain-offset spectrum. The editor is where the app bites, and it bites the maintainer hardest: someone who edits a preset a few times a year will have forgotten that the x is unconfirmed, that Save overwrites by name, and that the first A/B press is silent. The single biggest opportunity is one undo stack for the whole preset. It resolves the P0, most of the error-prevention gaps, and the persona flags at once.

## What's Working

1. **Honest pixels.** The bypass shifts the curve baseline by the match gain and the spectrum follows (EQCurveView.swift:359-364). The display never flatters the EQ.
2. **One colour per band, everywhere.** Handle, dashed response, and card border share it; there is never a hunt for which card is which.
3. **The popover holds still.** The permission banner swaps into the curve slot at fixed height (PopoverView.swift:35-49), so the menu-bar extra never jumps.

## Priority Issues

- **[P0] No undo for band edits or deletion.** *Why it matters:* PRODUCT.md promises "rare editing, so recoverable editing"; today one mis-click on an 8 pt x loses a band, and Revert is disabled whenever the working preset has no stored original (AppState.swift:519-529). *Fix:* register every band mutation (EditorView.swift:155-168, 202, 487) with the window's UndoManager, backed by a snapshot of `state.preset`, so ⌘Z works; move delete to the context menu or confirm it. *Suggested command:* /impeccable harden.
- **[P0] Accessibility is below the bar PRODUCT.md sets as a requirement.** *Why it matters:* the master switch is `Toggle("")` drawn as a Capsule with a tap gesture (PopoverView.swift:63, Controls.swift:13-23), so VoiceOver has no name for it and keyboard focus never reaches it; four icon-only buttons have no name; all 72 text sizes are fixed, so Larger Text does nothing. *Fix:* `.accessibilityLabel` on every icon-only control, a real Button inside the switch style, and text styles (`.caption2`, `.footnote`, `.monospacedDigit()`) instead of point sizes. *Suggested command:* /impeccable audit, then /impeccable polish.
- **[P1] Editor clamps gain to ±12 dB while AutoEq and peqdb presets exceed it.** *Why it matters:* an imported −15 dB band is drawn at −12 and snaps there on the first drag, silently changing the preset. *Fix:* derive the range from max(12, ceil(max |gain|)) and pass it to EQCurveView and the value row (EditorView.swift:148, 496; EQCurveView.swift:83). *Suggested command:* /impeccable harden.
- **[P1] Onboarding's "Start Listening" does the same as "Skip".** *Why it matters:* tapping a list row applies and closes instantly, so the prominent primary button has no job of its own (OnboardingView.swift:118-146). *Fix:* row selection highlights only; "Start Listening" applies the highlighted entry. *Suggested command:* /impeccable onboard.
- **[P2] Crossfeed appears in three surfaces with three control grammars.** *Why it matters:* button toggle in the popover, switch in the editor bar, switch plus a picker labelled "Preset" in Settings, and the editor bar mixes global settings into a preset-editing surface where Save does not save them. *Fix:* drop Crossfeed and Limiter from the editor bottom bar (EditorView.swift:238-270), rename the Settings picker "Profile", keep one switch style per context. *Suggested command:* /impeccable distill.

## Cognitive Load

Three of eight checklist items fail: grouping (crossfeed in three places), minimal choices (band-type menu offers 7 filter types, EditorView.swift:477; import format pills list 9; Settings has 5 tabs; preset menu is unbounded with a nested Delete submenu), and working memory (the first A/B press stores A and switches with no audible or visible change, AppState.swift:579-583). Moderate load, all of it in the editor.

## Emotional Journey

First launch is warm and honest about the purple dot, then dips when the primary onboarding button turns out to be a no-op. The daily glance is the peak: curve breathing behind the spectrum, latency readout, one switch. Editing is mixed: dragging nodes feels right and the bypass fade is a good reveal, but delete is a trapdoor. Import peaks at the live preview with "N filters recognized" and dips at the paste-tab error flicker. The end moment, closing the popover and forgetting it, works.

## Persona Red Flags

**Alex (Power User):** no keyboard nudge of nodes, no scroll-to-adjust Q, no fine-drag modifier; A/B first press is silent; Save overwrites by name without a prompt.

**Sam (VoiceOver / keyboard / Larger Text):** master switch, band delete, and value fields unreachable by keyboard (EditableValueField is a Text with onTapGesture, EditorView.swift:571-579); 9 to 13 pt fixed fonts ignore Larger Text; the popover is fixed at 360×410 with nowhere for text to grow.

**Riley (Stress Tester):** 32 bands in a strip with scroll indicators hidden and no scroll-to-selected (EditorView.swift:197); bands 11, 21, 31 repeat the colours of 1 to 10, so handles become ambiguous; Boost Range 100 % draws "100%" twice at the same x (PopoverView.swift:369-372); with no output device the menu opens empty while the slider still moves; malformed paste shows a raw error string.

**Malte (maintainer):** the popover a few times a week is excellent. Editing a few times a year is where memory fails: unconfirmed x, silent overwrite on Save, A/B priming click. Rare use argues for more guard rails, not fewer.

## Minor Observations

- Settings > Advanced: "Reset all settings…" label plus "Reset…" button doubles the ellipsis; the label says settings, the dialog also removes presets and profiles (SettingsView.swift:349-361).
- "I've enabled it →" uses a literal arrow glyph inside a button (OnboardingView.swift:71).
- "Delete Preset" lives inside the selection menu, an unusual home for a destructive action.
- Import format pills wrap at a hard 5 per row rather than by width (ImportSheet.swift:430-441).
- The Settings tab bar overlaps the form's top edge in the screenshot; native, but clumsy.
- Inside a band card, the type menu and the values are both 10 pt; the hierarchy is flat.

## Questions to Consider

- If Crossfeed and Limiter are global, why are they on the preset editing surface at all? Would removing them make "what does Save save" a question nobody asks?
- Would one undo stack for the whole preset be less work and more trust than confirming each destructive tap?
- Onboarding promises "Hear your music the way it was meant to sound." Does an app whose principle is honest sound want that sentence?
