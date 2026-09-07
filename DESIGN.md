---
name: OnlyEQ
description: A menu-bar system EQ that looks like Apple shipped it; the curve is the only thing that is ours.
colors:
  accent: "#0a84ff"
  label: "#ffffff"
  label-secondary: "rgba(255,255,255,0.55)"
  label-tertiary: "rgba(255,255,255,0.25)"
  label-quaternary: "rgba(255,255,255,0.10)"
  card-fill: "rgba(255,255,255,0.055)"
  card-hairline: "rgba(255,255,255,0.07)"
  control-background: "#1e1e1e"
  separator: "rgba(255,255,255,0.10)"
  track-off: "rgba(255,255,255,0.18)"
  knob: "#ffffff"
  boost-warning: "#ff9f0a"
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
typography:
  display:
    fontFamily: "-apple-system, SF Pro, system-ui, sans-serif"
    fontSize: "24px"
    fontWeight: 700
  title:
    fontFamily: "-apple-system, SF Pro, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 600
  body:
    fontFamily: "-apple-system, SF Pro, system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 400
  label:
    fontFamily: "-apple-system, SF Pro, system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 400
  caption:
    fontFamily: "-apple-system, SF Pro, system-ui, sans-serif"
    fontSize: "10px"
    fontWeight: 400
  value:
    fontFamily: "SF Mono, ui-monospace, Menlo, monospace"
    fontSize: "11px"
    fontWeight: 400
rounded:
  hairline: "1px"
  field: "4px"
  chip: "6px"
  panel: "8px"
  card: "12px"
  pill: "999px"
spacing:
  hair: "2px"
  xs: "4px"
  sm: "8px"
  md: "10px"
  lg: "12px"
  xl: "14px"
components:
  card:
    backgroundColor: "{colors.card-fill}"
    rounded: "{rounded.card}"
    padding: "12px"
  band-card:
    backgroundColor: "{colors.control-background}"
    rounded: "{rounded.panel}"
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
  chip:
    backgroundColor: "{colors.label-quaternary}"
    textColor: "{colors.label-secondary}"
    typography: "{typography.caption}"
    rounded: "{rounded.pill}"
    padding: "3px 8px"
  app-badge:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.label}"
    rounded: "{rounded.chip}"
    size: "24px"
---

# Design System: OnlyEQ

## Overview

**Creative North Star: "The Menu Bar Native"**

OnlyEQ should look like a utility Apple forgot to ship. Every colour is a system semantic colour that follows the user's accent and appearance; every typeface is San Francisco; every control is either a native SwiftUI control or a pixel-faithful stand-in for one. The app has no palette, no logo mark beyond an SF Symbol in an accent square, and no decoration. Brand lives in one place only: the frequency-response curve with the live spectrum breathing behind it, and the ten-colour band palette that ties graph handles to their cards.

Density is high and steady. The popover is four cards and a footer in a 360 point wide window at least 410 points tall, growing only with the system text size; the editor is a graph, a strip of small band cards, and two thin bars of controls. Text uses the system text styles from caption2 to body, values are monospaced, and nothing bounces. Controls are precise and restrained: a switch slides in 120 ms, bypass fades the graph in 150 ms, the spectrum attacks in 10 ms and releases over 400 ms, and that is the whole motion vocabulary.

**Key Characteristics:**
- System accent and system label colours only; the app never defines a hue of its own outside the band palette.
- Tonal layering, no shadows: cards are a 5.5 % tint with a 7 % hairline.
- One custom control family (switch, boost slider, curve editor), each drawn to match AppKit.
- Monospaced digits wherever a number can change.
- Motion is short, eased, and tied to a state change, never decorative.

## Colors

The palette is macOS itself; the tokens above are dark-appearance snapshots of dynamic system colours, which remain the source of truth in code.

### Primary
- **System Accent** (`Color.accentColor`, `NSColor.controlAccentColor`): the curve stroke, the curve fill gradient (35 % to 3 %), the output spectrum bars, on-state switch tracks, the app badge, and the boost slider fill. It is the only saturated colour on a resting screen.

### Neutral
- **Label** (`.primary`): headings and values.
- **Secondary Label** (`.secondary`): the workhorse; captions, axis labels, status text, and the grey input spectrum bars (43 uses across the UI).
- **Tertiary Label** (`.tertiary`): meter readouts and hints.
- **Quaternary Label** (`.quaternary` at 50 to 60 %): the fill behind editable value fields, chips, and the empty-list placeholder.
- **Card Tint** (`Color.primary` at 5.5 %) with **Card Hairline** (`Color.primary` at 7 %): the popover section surface.
- **Control Background** and **Separator** (`NSColor.controlBackgroundColor`, `.separatorColor`): band cards in the editor.
- **Track Off** (`Color.primary` at 18 %): a switch that is off; the volume slider track uses 12 %.

### Tertiary
- **Boost Warning** (`.orange`): the boost slider past 100 %, the only warning colour, and it appears only while the user is in the over-unity zone.
- **Band Palette** (`.blue, .teal, .purple, .pink, .orange, .green, .indigo, .mint, .red, .cyan`, cycling): a graph handle, its dashed individual response at 22 %, and its card border when selected all share one colour by index.

### Named Rules
**The One Hue Rule.** Outside the band palette and the boost warning, the only chromatic colour on screen is the user's accent. Never introduce a second brand colour.

**The Tint, Not Paint Rule.** Surfaces are `Color.primary` at low opacity so they read correctly in both appearances and with any accent. Never fill a surface with a literal grey.

## Typography

**Display Font:** San Francisco (system)
**Body Font:** San Francisco (system)
**Value Font:** SF Mono (system monospaced), or SF with monospaced digits

**Character:** Small, even, and quiet. The hierarchy is carried by weight and colour more than size; most text is 10 to 12 points and only onboarding uses anything above 20.

### Hierarchy
- **Display** (bold, 24 pt): onboarding welcome title only. A 40 pt and 34 pt SF Symbol appear beside it.
- **Title** (semibold, 13 pt): the app name in the popover header and window titles.
- **Body** (regular or medium, 12 pt): button labels, preset names, menu items.
- **Label** (regular, 11 pt): the workhorse for captions, form labels, and status.
- **Caption** (regular, 10 pt, secondary colour): axis labels, meter text, chips, band-card field names. 9 pt and 8 pt bold appear only inside graph handles and tick marks.
- **Value** (monospaced, 11 pt): Fc, Gain, Q, dB readouts, latency, and any number that updates live.

### Named Rules
**The Monospaced Number Rule.** Any number that can change while visible is set in monospaced digits so the layout does not shift.

**The Two-Step Rule.** Adjacent hierarchy levels differ by one point size or one weight step, never both, and never more.

## Layout

The popover is a vertical stack of cards at 10 pt spacing inside 14 pt padding, 360 pt wide and at least 410 pt tall, sized once when shown so the host window never resizes while open. Each card is 12 pt padded and full width. The editor is a single column: toolbar, graph filling the remaining height, a horizontally scrolling strip of 150 pt band cards at 8 pt spacing, then a bottom bar. Settings replaces the editor body with a grouped `Form` and a native tab bar. Sheets are fixed: onboarding 520 by 440 pt, import 560 by 470 pt.

The observed spacing values are 2, 4, 8, 10, 12, and 14 pt, with 8 and 10 dominating. Treat 4 as the unit for control internals and 8 or 10 for gaps between siblings. Labels on the graph sit 4 pt inside the plot edge; axis text is right-aligned to the plot.

## Elevation & Depth

Flat, by macOS convention. The popover and sheets get their shadow from the system window; nothing inside them casts one. Depth within a surface is tonal: a card is a 5.5 % tint with a 7 % hairline, a band card is the control background colour with a separator hairline that turns into a 1.5 pt band-coloured border when selected. The one exception is the switch and slider knob, which carry AppKit's 25 to 35 % black shadow at 1 to 1.5 pt radius because the real control does.

### Named Rules
**The System Casts The Shadow Rule.** Only windows, popovers, sheets, and control knobs have shadows, and only the ones AppKit would draw. Do not add shadows to cards, nodes, or hover states.

## Shapes

Continuous (squircle) corners at 12 pt for cards and 6 pt for the app badge and clipped previews. Standard corners at 8 pt for panels and band cards, 4 to 5 pt for value fields, 7 to 10 pt for sheet zones. Switches, chips, slider tracks, and the band-count badge are capsules. Graph handles are 12 pt circles with a white ring at 50 % (90 % when selected). Hairlines are 1 pt at 7 to 10 % primary.

## Components

### Card (popover)
- **Shape:** continuous 12 pt radius.
- **Fill:** `Color.primary` 5.5 % with a 1 pt 7 % hairline.
- **Padding:** 12 pt; children left-aligned, full width.
- **Disabled:** the whole card group drops to 45 % opacity when the engine is off.

### Switch (`AccentSwitchStyle`)
- A 34 by 20 pt capsule, accent when on, primary 18 % when off, white knob with a 25 % shadow, 1.5 pt inset, 120 ms ease-out slide. Drawn in SwiftUI so it renders in offscreen screenshots; it must stay indistinguishable from `NSSwitch`.

### Buttons
- Native SwiftUI `.bordered` and `.borderedProminent` at `.small` control size. Toggles that behave like buttons (Bypass, Crossfeed in the popover) use `.button` toggle style. There is no custom button.

### Value Field (`EditableValueField`)
- A 4 pt radius quaternary 50 % fill, monospaced 11 pt text, click to edit, Enter commits, values clamp to the canvas range.

### Chip
- A capsule with quaternary 60 % fill and 10 pt secondary text, used for import format names and the band count.

### Band Card
- 150 pt wide, 8 pt padding, control-background fill, separator hairline; the border becomes the band colour at 1.5 pt when selected; 50 % opacity when the band is disabled.

### Curve Editor (signature)
- Log-frequency plot from 20 Hz to 20 kHz. Grid is 1 pt secondary at 12 % dashed 2/3; the 0 dB line is 25 %. The composite response is a 2 pt accent stroke over a vertical accent gradient from 35 % to 3 %. Each band draws its own response dashed 4/3 at 22 % in its palette colour. Behind everything, 48 log-spaced spectrum bars: input in secondary label colour, output in accent, both at low alpha, with a 10 ms attack and 400 ms release on band power and a 2 dB/octave tilt so music reads flat. Bypass fades the graph to 45 % and hides the curve.

### Boost Slider
- A 5 pt capsule track at primary 12 %, accent fill, ticks at 0, 100, and 200 %, and the fill turns orange above unity.

## Do's and Don'ts

### Do:
- **Do** use `Color.accentColor`, `.primary`, `.secondary`, `.tertiary`, `.quaternary`, and `NSColor` semantic colours; that is how the app follows the user's accent and appearance.
- **Do** set every live number in monospaced digits.
- **Do** keep new controls native: `.bordered` buttons at `.small`, native menus, grouped forms in Settings.
- **Do** tie any animation to a state change and keep it under 200 ms with an ease curve.
- **Do** give every icon-only control an accessibility label and prefer text styles that scale with the system text size.

### Don't:
- **Don't** introduce a hex colour, a custom font, or a gradient outside the curve fill.
- **Don't** add shadows to cards, nodes, hover states, or anything AppKit would draw flat.
- **Don't** invent a second toggle look; a control that is on or off is a switch, a button toggle, or a checkbox, matching its neighbours on the same surface.
- **Don't** let the popover change size; it is fixed so the spectrum can redraw without relayout.
- **Don't** use the band palette for anything but bands.
