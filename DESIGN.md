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
  symbol-circle: "rgba(255,255,255,0.07)"
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
    backgroundColor: "{colors.symbol-circle}"
    textColor: "{colors.label-secondary}"
    rounded: "{rounded.pill}"
    size: "28px"
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

The popover is one instrument, not a stack of cards. Under the name and its switch, the live response spans the full width inside a hairline well, and the controls follow beneath it, reading top to bottom as the signal path: output device with volume, preset with its device binding and Bypass and Crossfeed, then Import, Equalizer, and the gear. Rows are separated by space, not by boxes. The whole thing sits on the system's own menu-bar material in a 360 point wide panel at least 420 points tall that grows only with the system text size. The editor, Settings, onboarding, and the import sheet are ordinary macOS windows: a unified toolbar, toolbar-style settings tabs, a setup assistant with a Back and Continue footer, a sheet with a segmented picker.

Motion is short, eased, and tied to a state change. A switch slides in 120 ms, bypass fades the plot in 150 ms, the band strip scrolls a selected card into view in 200 ms, and the spectrum attacks in 10 ms and releases over 400 ms. Every one of them is skipped under Reduce Motion, and that is the whole vocabulary.

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
- **Secondary Label** (`.secondary`): the workhorse for everything a person reads that is not a heading: captions, axis labels, form descriptions, the status pill text, the preset binding line, the input spectrum bars, and the circled symbols in the popover rows.
- **Tertiary Label** (`.tertiary`): decoration only. Two uses: the dashed border of the add-band button and the delete glyph on a band card.
- **Quaternary Label** (`.quaternary` at 50 to 60 %): the fill behind editable value fields and shortcut key caps.
- **Well Fill** (`Color.primary` at 3.5 %) with **Well Hairline** (`Color.primary` at 8 %): the plot well, the one surface the app draws.
- **Symbol Circle** (`Color.primary` at 7 %): the 28 pt circle behind the device and preset symbols in the popover.
- **Control Background** and **Separator** (`NSColor.controlBackgroundColor`, `.separatorColor`): band cards in the editor.
- **Track Off** (`Color.primary` at 18 %): a switch that is off. **Slider Track** (`Color.primary` at 12 %): the boost slider, with a 35 % tick at 100 %.
- **Panel Material** (`NSGlassEffectView` regular on macOS 26, `NSVisualEffectView` `.popover` behind-window before): what stands between the popover and the desktop. Notices inside the plot well use `.background` at 60 % (status pill) and 85 % (headphone suggestion) so they read over the spectrum.

### Tertiary
- **Boost Warning** (`.orange`): the boost slider past 100 %, the "waiting for audio" status dot, the peak meter between −3 and 0 dBFS, and import warnings. It appears only while something needs attention.
- **Status Active** (`.green`) and **Status Error** (`.red`): the status dot in the popover, the peak meter dot, the "access granted" checkmark, and fetch errors in the import sheet.
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

The popover is one `VStack` at 14 pt spacing inside 14 pt padding, 360 pt wide and at least 420 pt tall. Top to bottom: the header (22 pt app badge, the name, the switch at the trailing edge), the plot well at a fixed 150 pt with the status pill in its top-trailing corner and the compact axis labels 4 pt beneath, the device row with the boost slider, the preset row with its binding caption and Bypass and Crossfeed, and the footer (Import, Equalizer, and the gear menu with its system indicator). Each identity row is a 28 pt circled symbol, a 10 pt gap, a borderless menu, and its detail indented 38 pt underneath. The popover is sized once to its fitting size when shown, so the panel never resizes while open. It grows only with the system text size.

The editor window opens at 840 by 560 pt with a minimum of 720 by 480. Its unified 52 pt title bar carries real toolbar items (preset menu, Save, Revert on the left; Bypass in the centre; Import and the gear on the right) and hides the window title. Below it: the Compare row, a divider, the graph filling the remaining height with 24 pt side margins, a 122 pt horizontally scrolling strip of 150 pt band cards at 8 pt spacing, a divider, and the Preamp bar. Everything in the editor shares the 24 pt horizontal margin.

Settings is 560 pt wide with toolbar-style tabs (General, Devices, Sound, Shortcuts, Advanced, each an SF Symbol); each page is one grouped `Form` and the window resizes to the page. Onboarding is 560 pt wide and at least 460 tall: content, a divider, and a footer with Back on the left and Continue or Start Listening on the right at the large control size with 16 pt padding. The import sheet is 560 pt wide and at least 470 tall: a segmented picker at 12 pt padding, a divider, the tab body at 16 pt padding, a divider, and Cancel and Apply at 12 pt padding.

The observed spacing values are 2, 4, 6, 8, 10, 12, 14, 16, and 24 pt. Treat 4 as the unit for control internals, 8 or 10 for gaps between siblings, 14 for the popover's padding and the gap between its rows, 16 for window footers, and 24 for a window's side margin. Labels on the graph sit 4 pt inside the plot edge. Axis labels sit at their true log-scale positions; plots under about 300 pt wide label every second octave (20 Hz, 125, 500, 2 kHz, 8 kHz).

## Elevation & Depth

Flat, by macOS convention. The popover panel has the system shadow and the system material; the windows are ordinary windows. Nothing inside a window casts a shadow. Depth within a surface is tonal: the plot well is a 3.5 % tint with an 8 % hairline, a band card is the control background colour with a separator hairline that becomes a 1.5 pt band-coloured border when selected, and a notice over the spectrum is `.background` at 60 to 85 % with the same 8 % hairline. The one exception is the switch and slider knob, which carry AppKit's 25 to 35 % black shadow at 1 to 1.5 pt radius because the real control does.

### Named Rules
**The System Casts The Shadow Rule.** Only windows, popovers, sheets, and control knobs have shadows, and only the ones AppKit would draw. Do not add shadows to cards, nodes, or hover states.

**The One Surface Rule.** No cards: rows are separated by space; the plot alone sits in a hairline well, the one surface the app draws. Every plot outside the editor's canvas sits in the same one. The well is the `plotWell()` modifier: `Color.primary` at 3.5 % with a 1 pt 8 % hairline and 10 pt continuous corners. The popover plot, the onboarding sample curve, both preview curves in the import sheet, and the import drop well share it. The editor graph is the only exception; it fills its window edge to edge.

## Shapes

Continuous (squircle) corners at 14 pt for the popover panel, 10 pt for the plot well and drop well, 8 pt for notices over the plot, and 27 % of the badge size for the app badge. Standard corners at 8 pt for band cards and the add-band button, 7 pt for the headphone-suggestion banner in the import sheet, 5 pt for shortcut key caps, and 4 pt for value fields. Switches, the status pill, slider tracks, and the circled row symbols are capsules or circles. Graph handles are 11 pt circles with a 1 pt white ring at 50 %, growing to 14 pt with a 2 pt ring at 90 % when selected. Hairlines are 1 pt at 8 % primary, or the system separator colour.

## Components

### Plot Well (signature surface)
- **Shape:** continuous 10 pt radius, clipped; applied with the `plotWell()` modifier.
- **Fill:** `Color.primary` 3.5 % with a 1 pt 8 % hairline.
- **Contents:** the curve, its axis labels 4 pt below at caption2 secondary, and any notice in the corner. Heights: 150 pt in the popover and onboarding, 110 and 80 pt for the import previews.
- **Drop variant:** the import drop well uses the same shape; while a file hovers it switches to accent 8 % fill with a solid accent stroke, and the document symbol turns accent.

### Switch (`AccentSwitchStyle`)
- A 34 by 20 pt capsule, accent when on, primary 18 % when off, white knob with a 25 % shadow, 1.5 pt inset, 120 ms ease-out slide. Drawn in SwiftUI so it renders in offscreen screenshots; it must stay indistinguishable from `NSSwitch`. Focusable, toggles on Space, and presents to VoiceOver as the Toggle it stands in for. Settings rows use the real `.switch` at `.mini`.

### Buttons
- Native SwiftUI `.bordered` and `.borderedProminent`. Popover buttons are `.small`; onboarding footers are `.large`; toolbar items and sheet footers are the default size. Toggles that behave like buttons (Bypass, Crossfeed) use `.button` toggle style. A Compare slot is a bordered button tinted accent when selected. There is no custom button.

### Identity Row (`IdentityRow`)
- A 28 pt circle at primary 7 % holding a callout-weight secondary SF Symbol, a 10 pt gap, a borderless-button menu with a body-medium label truncated in the middle, and a detail block indented 38 pt. Full width of the popover. The device row's detail is the boost slider; the preset row's is the binding caption plus Bypass and Crossfeed.

### Status Pill
- A capsule of `.background` at 60 % with 7 by 3 pt padding, a 6 pt dot (green active, secondary off or bypassed, orange waiting, red error), and caption2 medium secondary text with monospaced digits. Sits 8 pt inside the top-trailing corner of the popover plot.

### Value Field (`EditableValueField`)
- A 4 pt radius quaternary 50 % fill, caption text with monospaced digits right-aligned, 2 by 4 pt padding. Resting state is a button; click to edit, Enter commits, Escape cancels, values clamp to the canvas range.

### Key Cap
- A 5 pt radius quaternary 60 % fill with 8 by 3 pt padding and subheadline SF Mono text, showing a global shortcut chord in Settings.

### Band Card
- 150 pt wide, 8 pt padding, control-background fill, separator hairline; the border becomes the band colour at 1.5 pt when selected; 50 % opacity when the band is disabled. Header: an 8 pt colour dot, the band number in caption semibold secondary, a borderless type menu, and a tertiary delete glyph. Three value rows below. The add-band button beside the strip is a 44 by 100 pt plain button with a tertiary 1 pt dashed border.

### Curve Editor (signature)
- Log-frequency plot from 20 Hz to 20 kHz. Grid is 1 pt secondary at 12 % dashed 2/3 on octaves; the 0 dB line is 25 %. The composite response is a 2 pt accent stroke over a vertical accent gradient from 35 % to 3 %. In the editor each band draws its own response dashed 4/3 at 22 % in its palette colour. Behind everything, log-spaced spectrum bars in an AppKit layer: input in secondary label colour, output in accent, both at low alpha, with a 10 ms attack and 400 ms release on band power, a 45 ms interpolation at the display rate, and the output shifted by the static gain so only the filter shape shows. Bypass fades the plot to 45 to 50 % and hides the curve.

### Boost Slider
- A 5 pt capsule track at primary 12 %, accent fill, a 2 by 9 pt tick at 100 %, a 15 pt white knob with a 35 % shadow, and the fill turns orange above unity. Tick labels (0 %, 100 %, max) in caption2 secondary sit under the track.

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
