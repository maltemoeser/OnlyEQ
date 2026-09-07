---
version: 1
slug: "sources-onlyeq-ui-popoverview-swift"
primary_target: "Sources/OnlyEQ/UI/PopoverView.swift"
related_targets: ["Sources/OnlyEQ/App/AppDelegate.swift"]
---

## Scope and mode

The menu-bar popover (`Sources/OnlyEQ/UI/PopoverView.swift`), Operate. The daily surface: opened for a glance, closed within seconds.

## Audience, job, task, proof, constraints

- The maintainer with a known headphone preset; fluent Mac user.
- Job: confirm the EQ is doing its work on the right device with the right preset; occasionally flip Bypass, adjust volume, or switch device.
- Proof on screen: the live response curve with the input and output spectrum breathing under it; the preset's device binding named in words.
- Constraints: fixed size once shown (grows only with system text size); every control native; no motion beyond state changes; must read the same in light and dark.

## Chosen direction

Curve-first stack (surface seed 1512465f rolled candidate 7, the two-pane form; the user chose candidate 2, the stack). The plot spans the full width under the name and switch with the status pill in its corner; the controls follow beneath and read as the signal path: OnlyEQ and its switch, output device with volume, preset with binding caption and Bypass | Crossfeed, then Import…, Equalizer, and the gear. The panel uses the system menu-bar material (Liquid Glass on macOS 26, popover vibrancy before). The memorable moment: pressing Bypass empties the plot to the grey input spectrum, so hearing it flat and seeing it flat are one act.

## Unresolved

- Whether the plot should show the band handles read-only at this size.
- Whether the status pill should carry the peak level when the limiter engages.
