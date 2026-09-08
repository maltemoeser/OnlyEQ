---
name: OnlyEQ
description: A menu-bar system EQ that looks like Apple shipped it; the curve is the only thing that is ours.
colors:
  accent: "#0a84ff"
  label: "#ffffff"
  label-secondary: "rgba(255,255,255,0.55)"
  label-tertiary: "rgba(255,255,255,0.25)"
  label-quaternary: "rgba(255,255,255,0.10)"
  well-fill: "rgba(255,255,255,0.035)"
  well-hairline: "rgba(255,255,255,0.08)"
  control-background: "#1e1e1e"
  separator: "rgba(255,255,255,0.10)"
  track-off: "rgba(255,255,255,0.18)"
  slider-track: "rgba(255,255,255,0.12)"
  knob: "#ffffff"
  boost-warning: "#ff9f0a"
  status-active: "#30d158"
  status-error: "#ff453a"
  band-1: "#0a84ff"
  band-2: "#5ac8fa"
  band-3: "#bf5af2"
  band-4: "#ff375f"
  band-5: "#ff9f0a"
  band-6: "#30d158"
  band-7: "#5e5ce6"
  band-8: "#66d4cf"
  band-9: "#ff453a"
  band-10: "#64d2ff"
  band-11: "#ffd60a"
  band-12: "#ac8e68"
typography:
  title:
    fontFamily: "-apple-system, SF Pro, system-ui, sans-serif"
    fontSize: "22px"
    fontWeight: 700
  title2:
    fontFamily: "-apple-system, SF Pro, system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 700
  title3:
    fontFamily: "-apple-system, SF Pro, system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 600
  headline:
    fontFamily: "-apple-system, SF Pro, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 600
  body:
    fontFamily: "-apple-system, SF Pro, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
  callout:
    fontFamily: "-apple-system, SF Pro, system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 400
  subheadline:
    fontFamily: "-apple-system, SF Pro, system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 400
  caption:
    fontFamily: "-apple-system, SF Pro, system-ui, sans-serif"
    fontSize: "10px"
    fontWeight: 400
  caption2:
    fontFamily: "-apple-system, SF Pro, system-ui, sans-serif"
    fontSize: "10px"
    fontWeight: 400
  value:
    fontFamily: "-apple-system, SF Pro, system-ui, sans-serif"
    fontSize: "10px"
    fontWeight: 400
    fontFeature: "tnum"
  mono:
    fontFamily: "SF Mono, ui-monospace, Menlo, monospace"
    fontSize: "11px"
    fontWeight: 400
rounded:
  hairline: "1px"
  field: "4px"
  keycap: "5px"
  badge: "6px"
  notice: "8px"
  well: "10px"
  popover: "14px"
  pill: "999px"
spacing:
  hair: "2px"
  xs: "4px"
  sm: "6px"
  md: "8px"
  lg: "10px"
  xl: "12px"
  pane: "14px"
  row: "16px"
  window: "24px"
components:
  plot-well:
    backgroundColor: "{colors.well-fill}"
    rounded: "{rounded.well}"
  drop-well-targeted:
    backgroundColor: "rgba(10,132,255,0.08)"
    rounded: "{rounded.well}"
  band-card:
    backgroundColor: "{colors.control-background}"
    rounded: "{rounded.notice}"
    padding: "8px"
    width: "150px"
  switch:
    backgroundColor: "{colors.track-off}"
    rounded: "{rounded.pill}"
    width: "34px"
    height: "20px"
  switch-on:
    backgroundColor: "{colors.accent}"
    rounded: "{rounded.pill}"
    width: "34px"
    height: "20px"
  value-field:
    backgroundColor: "{colors.label-quaternary}"
    typography: "{typography.value}"
    rounded: "{rounded.field}"
    padding: "2px 4px"
  status-pill:
    typography: "{typography.caption2}"
    textColor: "{colors.label-secondary}"
    rounded: "{rounded.pill}"
    padding: "3px 7px"
  key-cap:
    backgroundColor: "{colors.label-quaternary}"
    typography: "{typography.mono}"
    rounded: "{rounded.keycap}"
    padding: "3px 8px"
  identity-symbol:
    textColor: "{colors.label-secondary}"
    size: "22px"
  app-badge:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.label}"
    rounded: "{rounded.badge}"
    size: "22px"
---

# Design System: OnlyEQ

## Overview

**Creative North Star: "The Menu Bar Native"**

OnlyEQ should look like a utility Apple forgot to ship. Every colour is a system semantic colour that follows the user's accent and appearance; every typeface is San Francisco through the system text styles; every control is either a native SwiftUI control or a pixel-faithful stand-in for one. The app has no palette, no logo mark beyond an SF Symbol in an accent square, and no decoration. Brand lives in one place only: the frequency-response curve with the live spectrum breathing behind it, and the band palette that ties graph handles to their cards.

The popover is one instrument, not a stack of cards. Under the name, its latency in small type, and its switch, the plot fills the width inside a hairline well: the live spectrum leads and the response is a thin line over it, with a vertical volume fader at the plot's side and a pill in the corner only when something is off (bypassed, waiting for audio, error). Bypass and Crossfeed follow as two small capsule toggles, kin to the pill, with the output device as a capsule pull-down at the row's end; then the preset in semibold with the checkbox that binds it to the device, and a hairline with a bordered Open Equalizer… and the gear. Rows are separated by space, not by boxes. The whole thing sits on the system's own menu-bar material in a 360 point wide panel about 350 points tall that grows only with the system text size. The editor, Settings, onboarding, and the import sheet are ordinary macOS windows: a unified toolbar, toolbar-style settings tabs, a setup assistant with a Back and Continue footer, a sheet with a segmented picker.

Motion is short, eased, and tied to a state change. A switch slides in 120 ms, bypass eases the response onto the 0 dB line over 350 ms while the plot dims, the band list scrolls a selected row into view in 200 ms, and the spectrum attacks in 10 ms and releases over 400 ms. Every one of them is skipped under Reduce Motion, and that is the whole vocabulary.

**Key Characteristics:**
- System accent and system label colours only; the app never defines a hue of its own outside the band palette.
- One drawn surface: the plot well, a 3.5 % tint with an 8 % hairline at a 10 pt continuous corner. Everything else is a native window, material, or form.
- One custom control family (switch, boost slider, curve editor), each drawn to match AppKit.
- Text uses the system text styles, so every window's height follows the system text size.
- Secondary label for anything a person reads; tertiary only for decoration.

## Colors

The palette is macOS itself; the tokens above are dark-appearance snapshots of dynamic system colours, which remain the source of truth in code.

### Primary
- **System Accent** (`Color.accentColor`, `NSColor.controlAccentColor`): the curve stroke, the curve fill gradient (35 % to 3 %), the output spectrum bars, on-state switch tracks, the app badge, the boost slider fill, the selected Compare slot tint, the drop well while a file hovers over it (8 % fill, solid stroke), and the headphone-suggestion banner (9 % fill). It is the only saturated colour on a resting screen.

### Neutral
- **Label** (`.primary`): headings, values, menu labels, the plot's 0 dB line.
- **Secondary Label** (`.secondary`): the workhorse for everything a person reads that is not a heading: captions, axis labels, form descriptions, the status pill text, the preset binding checkbox, the input spectrum bars, and the row symbols in the popover.
- **Tertiary Label** (`.tertiary`): decoration only. One use: the delete glyph on a band row.
- **Quaternary Label** (`.quaternary` at 50 to 60 %): the fill behind editable value fields and shortcut key caps.
- **Well Fill** (`Color.primary` at 3.5 %) with **Well Hairline** (`Color.primary` at 8 %): the plot well, the one surface the app draws.
- **Track Off** (`Color.primary` at 18 %): a switch that is off. **Slider Track** (`Color.primary` at 12 %): the 4 pt vertical fader track, accent to 100 %, orange above it, with a 35 % tick at 100 %.
- **Panel Material** (`NSGlassEffectView` regular on macOS 26, `NSVisualEffectView` `.popover` behind-window before): what stands between the popover and the desktop. Notices inside the plot well use `.background` at 60 % (status pill) and 85 % (headphone suggestion) so they read over the spectrum.

### Tertiary
- **Boost Warning** (`.orange`): the boost slider past 100 %, the "waiting for audio" status dot, the peak meter between −3 and 0 dBFS, and import warnings. It appears only while something needs attention.
- **Status Active** (`.green`) and **Status Error** (`.red`): the status dot in the popover, the peak meter dot (coloured by the held maximum, not the moment), the "access granted" checkmark, and fetch errors in the import sheet.
- **Band Palette** (`.blue, .teal, .purple, .pink, .orange, .green, .indigo, .mint, .red, .cyan, .yellow, .brown`, then golden-ratio hues at 60 % saturation so 32 bands never repeat): a graph handle, its dashed individual response at 22 %, its card dot, and its card border when selected all share one colour by index.

### Named Rules
**The One Hue Rule.** Outside the band palette and the status colours, the only chromatic colour on screen is the user's accent. Never introduce a second brand colour.

**The Tint, Not Paint Rule.** Surfaces are `Color.primary` at low opacity so they read correctly in both appearances and with any accent. Never fill a surface with a literal grey.

**The Read It In Secondary Rule.** Text a person reads is primary or secondary label. Tertiary is reserved for decoration that carries no information on its own: the add-band dashed border and the delete glyph.

## Typography

**Display Font:** San Francisco (system)
**Body Font:** San Francisco (system)
**Value Font:** San Francisco with monospaced digits; SF Mono only for pasted EQ text and shortcut chords

**Character:** Small, even, and quiet. The hierarchy is carried by weight and colour more than size. Every run of text is a system text style, so a larger system text size makes every window taller instead of clipping. The sizes below are the macOS defaults, not fixed values.

### Hierarchy
- **Title** (bold, `.title`): "Welcome to OnlyEQ" only, beside a 30 pt app badge.
- **Title 2** (bold, `.title2`): the onboarding step headings. A 40 pt SF Symbol appears above the permission step.
- **Title 3** (semibold, `.title3`): the drop well heading, under a 34 pt document symbol.
- **Headline** (semibold, `.headline`): the Save Preset sheet title.
- **Body** (semibold or medium, `.body`): the app name in the popover header and the device and preset menu labels beside it.
- **Callout** (`.callout`): notice headings at semibold, onboarding paragraphs and list rows at regular or medium.
- **Subheadline** (`.subheadline`): editor bottom-bar labels, import sheet body text, settings menu labels.
- **Caption** (`.caption`): the workhorse for captions, band-card field values, the Compare row, form-like rows in the import preview.
- **Caption 2** (`.caption2`): axis labels, the status pill, the ±dB corner labels, the spectrum legend, band-card field names, and slider tick labels.
- **Value** (`.caption.monospacedDigit()`, `.subheadline.monospacedDigit()`): Fc, Gain, Q, dB readouts, percentages, latency, and any number that updates live.
- **Mono** (`.system(.subheadline, design: .monospaced)`): the paste editor and shortcut key caps.

### Named Rules
**The Monospaced Number Rule.** Any number that can change while visible is set in monospaced digits so the layout does not shift.

**The Text Style Rule.** Text takes a system text style, never a point size. The three exceptions are SF Symbols used as illustrations (40, 34, and half the badge size).

## Layout

The popover is one `VStack` inside 14 pt side padding, 360 pt wide and about 350 pt tall, with a spacing rhythm of tight inside a group and generous between groups: header (badge, name, caption latency, switch), 10 pt, the plot row (the well at a fixed 150 pt with the compact axis labels 4 pt beneath, then 10 pt and the 30 pt fader column whose track spans the well's height and whose readout sits on the axis line), 8 pt, the listening row (Bypass and Crossfeed as small text capsule toggles leading, the output device as a small text capsule pull-down trailing), 18 pt, the preset row in semibold with its "Use automatically on <device>" small checkbox, 14 pt, then a hairline and the footer (a text-only bordered Open Equalizer… and the gear menu with its system indicator) 10 pt below it. The preset row is a 22 pt secondary symbol (`waveform.path`), an 8 pt gap, a borderless menu, and its detail indented 30 pt underneath. The popover is sized once to its fitting size when shown, so the panel never resizes while open. It grows only with the system text size.

The editor window opens at 840 by 616 pt with a minimum of 720 by 536. Its unified 52 pt title bar carries real toolbar items (preset menu, Save…, and Revert as an `arrow.counterclockwise` glyph on the left; Bypass and the gear on the right) and hides the window title. Import… lives in the preset menu, after the presets. The verbs are words; the one glyph is the undo arrow. Below it: the Compare row with 8 pt above and below, a divider, the graph filling the remaining height with 24 pt side margins, a 158 pt band list of 22 pt rows in two columns (three from 1056 pt wide), filled top to bottom then left to right and ordered low to high in frequency so it reads like the graph (the order holds still for the length of a node drag); ten bands and the Add Band row fit without scrolling, longer presets scroll vertically. Under it, a divider and the Adjust bar: Bass, Treble, Tilt, and Strength sliders in two rows with a Reset button, the simple way to tune a profile, always in view so the reason a curve leaves its handles is never hidden. Then a divider and the Preamp bar: the Preamp label, readout, and slider with the Auto checkbox on the left, and on the right, under its own "Output" label, the peak meter. Everything in the editor shares the 24 pt horizontal margin.

Settings is 560 pt wide with toolbar-style tabs (General, Devices, Sound, Shortcuts, Advanced, each an SF Symbol); each page is one grouped `Form` and the window resizes to the page. Onboarding is 560 pt wide and at least 460 tall: content, a divider, and a footer with Back on the left and Continue or Start Listening on the right at the large control size with 16 pt padding. The import sheet is 560 pt wide and at least 470 tall: a segmented picker at 12 pt padding, a divider, the tab body at 16 pt padding, a divider, and Cancel and Apply at 12 pt padding.

The observed spacing values are 2, 4, 6, 8, 10, 12, 14, 16, and 24 pt. Treat 4 as the unit for control internals, 8 or 10 for gaps between siblings, 14 for the popover's padding and the gap between its rows, 16 for window footers, and 24 for a window's side margin. Labels on the graph sit 4 pt inside the plot edge. Axis labels sit at their true log-scale positions; plots under about 300 pt wide label every second octave (20 Hz, 125, 500, 2 kHz, 8 kHz).

## Elevation & Depth

Flat, by macOS convention. The popover panel has the system shadow and the system material; the windows are ordinary windows. Nothing inside a window casts a shadow. Depth within a surface is tonal: the plot well is a 3.5 % tint with an 8 % hairline, a selected band row is a 5 pt rounded fill of its band colour at 18 %, and a notice over the spectrum is `.background` at 60 to 85 % with the same 8 % hairline. The one exception is the switch and slider knob, which carry AppKit's 25 to 35 % black shadow at 1 to 1.5 pt radius because the real control does.

### Named Rules
**The System Casts The Shadow Rule.** Only windows, popovers, sheets, and control knobs have shadows, and only the ones AppKit would draw. Do not add shadows to cards, nodes, or hover states.

**The One Surface Rule.** No cards: rows are separated by space; the plot alone sits in a hairline well, the one surface the app draws. Every plot outside the editor's canvas sits in the same one. The well is the `plotWell()` modifier: `Color.primary` at 3.5 % with a 1 pt 8 % hairline and 10 pt continuous corners. The popover plot, the onboarding sample curve, both preview curves in the import sheet, and the import drop well share it. The editor graph is the only exception; it fills its window edge to edge.

## Shapes

Continuous (squircle) corners at 14 pt for the popover panel, 10 pt for the plot well and drop well, 8 pt for notices over the plot, and 27 % of the badge size for the app badge. Standard corners at 7 pt for the headphone-suggestion banner in the import sheet, 5 pt for shortcut key caps and the selected band row, and 4 pt for value fields. Switches, the status pill, and slider tracks are capsules. Graph handles are 11 pt circles with a 1 pt white ring at 50 %, growing to 14 pt with a 2 pt ring at 90 % when selected. Hairlines are 1 pt at 8 % primary, or the system separator colour.

## Components

### Plot Well (signature surface)
- **Shape:** continuous 10 pt radius, clipped; applied with the `plotWell()` modifier.
- **Fill:** `Color.primary` 3.5 % with a 1 pt 8 % hairline.
- **Contents:** the curve, its axis labels 4 pt below at caption2 secondary, and any notice in the corner. Heights: 150 pt in the popover and onboarding, 110 and 80 pt for the import previews.
- **Drop variant:** the import drop well uses the same shape; while a file hovers it switches to accent 8 % fill with a solid accent stroke, and the document symbol turns accent.

### Switch (`AccentSwitchStyle`)
- A 34 by 20 pt capsule, accent when on, primary 18 % when off, white knob with a 25 % shadow, 1.5 pt inset, 120 ms ease-out slide. Drawn in SwiftUI so it renders in offscreen screenshots; it must stay indistinguishable from `NSSwitch`. Focusable, toggles on Space, and presents to VoiceOver as the Toggle it stands in for. Settings rows use the real `.switch` at `.mini`.

### Buttons
- Native SwiftUI `.bordered` and `.borderedProminent`. Popover toggles and the device pull-down are `.small` text capsules (`.buttonBorderShape(.capsule)`; the pull-down is a `Menu` in `.button` style) and the footer's Open Equalizer… is a default-size text-only `.bordered` button; onboarding footers are `.large`; toolbar items and sheet footers are the default size. Toggles that behave like buttons (Bypass, Crossfeed) use `.button` toggle style; a setting that binds or unbinds (the preset's device binding) is a `.checkbox` toggle. A Compare slot is a bordered button tinted accent when selected. There is no custom button.

### Identity Row (`IdentityRow`)
- A 22 pt column holding a body-size secondary SF Symbol, an 8 pt gap, a borderless-button menu with a body-semibold label truncated in the middle, and a detail block indented 30 pt. Full width of the popover. One use: the preset row, whose symbol is `waveform.path` and whose detail is the "Use automatically on <device>" checkbox. One glyph per meaning across the app: `waveform.path` is the preset, `arrow.counterclockwise` is Revert (the uturn arrow stays Undo's), `waveform.slash` is bypassed, `gearshape` is the gear; Open Equalizer… and Import… carry no glyph.

### Status Pill
- A capsule of `.background` at 60 % with 7 by 3 pt padding, a 6 pt dot (secondary bypassed, orange waiting, red error), and caption2 medium secondary text. Sits 8 pt inside the top-trailing corner of the popover plot, and only while something is off: plain running is the switch being on, and the latency is a caption beside the name.

### Value Field (`EditableValueField`)
- A 4 pt radius quaternary 50 % fill, caption text with monospaced digits right-aligned, 2 by 4 pt padding. Resting state is a button; click to edit, Enter commits, Escape cancels, values clamp to the canvas range.

### Key Cap
- A 5 pt radius quaternary 60 % fill with 8 by 3 pt padding and subheadline SF Mono text, showing a global shortcut chord in Settings.

### Band Row
- A 22 pt row, 4 pt side padding, 5 pt spacing: an 8 pt colour dot, the band number in caption semibold secondary right-aligned in 16 pt, a borderless type menu in a 72 pt column, then frequency, gain, and Q as 60, 58, and 50 pt value fields (the Q field reads "Q 1.41" so it names itself), and a tertiary delete glyph. Selected: a 5 pt rounded fill of the band colour at 18 %. 50 % opacity when the band is disabled. The last row is Add Band, a plain caption button with a `plus` glyph in secondary; the new band lands at the centre of the widest gap between the existing bands on the log axis, never on a neighbour.

### Adjust Bar
- An "Adjust" subheadline secondary label, then a two-by-two grid (24 pt between columns, 6 pt between rows) of Bass and Treble over Tilt and Strength, 8 pt vertical padding. Each cell: a 56 pt subheadline secondary label, a small slider that takes the remaining width, and a 64 pt subheadline medium monospaced readout aligned on the unit ("+1.5 dB", "0.0 dB", "85%", "Off" at zero strength). Bass and Treble are ±6 dB shelves at 105 Hz and 2.5 kHz, Tilt is ±6 dB at the ends about 1 kHz, Strength is 0 to 100 % of the bands' gain. A small bordered Reset button trails the grid, disabled when everything is neutral. Arrow keys move a slider one step (0.5 dB, 5 %). The graph keeps its handles on the preset's bands and draws the composite of what is heard.

### Curve Editor (signature)
- Log-frequency plot from 20 Hz to 20 kHz. Grid is 1 pt secondary at 12 % dashed 2/3 on octaves; the 0 dB line is 25 %. The composite response is a 2 pt accent stroke over a vertical accent gradient from 35 % to 3 % in the editor and previews; in the popover it is a 1.5 pt line at 90 % with no fill, and the spectrum bars run at 22 % and 85 % height so the music leads and the curve reads over it. In the editor each band draws its own response dashed 4/3 at 22 % in its palette colour. Behind everything, log-spaced spectrum bars in an AppKit layer: input in secondary label colour, output in accent, both at low alpha, with a 10 ms attack and 400 ms release on band power, a 45 ms interpolation at the display rate, and the output shifted by the static gain so only the filter shape shows. Bypass dims the plot to 55 % and eases the response onto the 0 dB line, so the curve settles flat rather than vanishing.

### Boost Slider
- A vertical 30 pt column: a 4 pt capsule track at primary 12 % spanning the plot well's height, accent fill, an 8 by 2 pt tick at 100 %, a 13 pt white knob with a 35 % shadow, and the fill turns orange above unity. The readout ("65%", or "Off" at zero) sits under the track on the axis line in caption2 medium monospaced digits, secondary, turning orange in the boost zone. The knob reaches the well's top line.

### App Badge
- An accent square (22 pt default, 30 pt in onboarding) with a continuous corner at 27 % of its size and a bold white `chart.bar.fill` at half size. It is the only logo mark. The menu-bar item shows the same symbol as a template image, filled while the EQ shapes sound and outlined (`chart.bar`) while off or bypassed.

## Do's and Don'ts

### Do:
- **Do** use `Color.accentColor`, `.primary`, `.secondary`, `.tertiary`, `.quaternary`, and `NSColor` semantic colours; that is how the app follows the user's accent and appearance.
- **Do** put every plot outside the editor's canvas in the plot well, and nothing else in a well of its own.
- **Do** set every live number in monospaced digits and every run of text in a system text style.
- **Do** keep new controls native: bordered buttons, native menus, real toolbar items, grouped forms in Settings, a setup-assistant footer in onboarding.
- **Do** tie any animation to a state change, keep it under 200 ms with an ease curve, and skip it under Reduce Motion.
- **Do** give every icon-only control an accessibility label and every custom control a VoiceOver representation.

### Don't:
- **Don't** introduce a hex colour, a custom font, or a gradient outside the curve fill.
- **Don't** add cards, boxes, or shadows to group rows; separate them with space.
- **Don't** use tertiary label for anything a person has to read.
- **Don't** invent a second toggle look; a control that is on or off is a switch, a button toggle, or a checkbox, matching its neighbours on the same surface.
- **Don't** let the popover change size while open; it is sized once when shown so the spectrum can redraw without relayout.
- **Don't** use the band palette for anything but bands.
