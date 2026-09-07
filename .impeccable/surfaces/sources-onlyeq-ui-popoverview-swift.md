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
- Proof on screen: the live response curve with the input and output spectrum breathing under it; the preset's device binding as a checkbox that names the device.
- Constraints: fixed size once shown (grows only with system text size); every control native; no motion beyond state changes; must read the same in light and dark.

## Chosen direction

Curve-first stack (surface seed 1512465f rolled candidate 7, the two-pane form; the user chose candidate 2, the stack). The plot fills the width under the name, its latency, and the switch: the live spectrum leads and the response is a thin line over it, a vertical volume fader stands at the plot's side, and a pill appears in the corner only for bypassed, waiting, or error. Bypass and Crossfeed sit as two small text capsule toggles under the axis with the output device as a text capsule pull-down at the row's end; then the preset in semibold with its "Use automatically on <device>" checkbox, and a hairline with a bordered Open Equalizer… and the gear. Import lives in the preset menu. The panel uses the system menu-bar material (Liquid Glass on macOS 26, popover vibrancy before). The memorable moment: pressing Bypass eases the curve onto the 0 dB line over the moving spectrum, so hearing it flat and seeing it flat are one act.

## Unresolved

- Whether the plot should show the band handles read-only at this size.
- Whether the status pill should carry the peak level when the limiter engages.
