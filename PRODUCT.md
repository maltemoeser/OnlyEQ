# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

Native macOS (AppKit + SwiftUI, macOS 14.4+). `ios` is the closest schema value; read it as "Apple platform, follow the macOS Human Interface Guidelines", not iPhone.

## Users

The maintainer, on their own Macs, listening on headphones with a known correction preset (currently a Sennheiser HD 650 with an oratory1990 profile). Other people install the fork, but design decisions optimise for one experienced user who understands parametric EQ, not for first-timers.

## Product Purpose

A system-wide parametric EQ that lives in the menu bar and needs nothing installed: no virtual audio driver, no password, no coreaudiod restart. Success in daily use is set once, forget: pick a headphone preset, close the popover, and never think about it again. Editing is rare.

## Positioning

Uses the macOS 14.4 process-tap API instead of a virtual audio driver, so volume keys keep working, Bluetooth devices do not distort, apps cannot escape the EQ by pinning their output, and macOS updates do not break it. The fork adds level-matched bypass, Vicanek matched biquads, crossfeed, ISO 226 loudness compensation, and an input-versus-output spectrum, and ships signed updates from its own GitHub Releases.

## Operating Context

- Menu-bar extra with a popover (preset, bypass, crossfeed, volume, device, live curve), one editor window that also hosts Settings, an import sheet, and a first-run onboarding flow.
- Headphone presets come from AutoEq and peqdb, imported by file drop, paste, or in-app search. Per-device profiles switch automatically when headphones connect.
- Global hotkeys toggle the EQ and cycle output devices. Launch at login is expected.
- The purple "recording" indicator is always on while the EQ runs; that is a known trade-off, not a bug.
- Builds with SwiftPM and the Command Line Tools only; no Xcode project, no asset catalogs. Self-tests run inside the binary (`swift run OnlyEQ --test`). README screenshots are rendered by `--screenshots`.
- Releases: push a `v*` tag, GitHub Actions builds, signs with Sparkle, and publishes; installed copies auto-update.

## Capabilities and Constraints

- Filter types: peak, low/high shelf, low/high pass, notch, band pass; band count uncapped in principle, 32 in the editor.
- Preamp with Auto mode, output boost to 200 %, stereo-linked limiter, A/B slots, bypass that keeps preamp and limiter so A/B is level-matched.
- Realtime constraint: the IO callback must not allocate; filter changes swap atomically.
- Terminology the app uses: Bypass (not Flat), Preamp, Boost, Crossfeed, Loudness compensation, Reference volume, Fc / Gain / Q.
- Latency about 10 ms at the default 256-frame buffer; an exclude list handles DAWs and conferencing apps.
- Undecided: whether Crossfeed and Limiter are per-preset or global (today they behave as global settings but are toggled from the preset row); undo for band edits does not exist yet.

## Brand Commitments

Name: OnlyEQ. Menu-bar and welcome icon: `chart.bar.fill`. Accent: the system accent colour. No custom brand palette or typeface. Voice in copy and README: plain, first person, honest about trade-offs.

## Evidence on Hand

- `docs/screenshots/` popover.png, editor.png, settings.png, import.png (dark appearance), app-icon.png.
- Credits in README name the projects the feature set borrows from (SoundMax, eqMac, SoundSource, FineTune, AutoEq, peqdb, RBJ cookbook, AudioCap).
- No testimonials, user numbers, or benchmarks exist; do not invent any.

## Product Principles

- Nothing to install and nothing to babysit; every control earns its place in the popover.
- Native first: system controls, system colours, standard menu-bar-extra behaviour over custom styling.
- Honest sound: bypass, spectrum, and gain alignment must never make the EQ look or sound better than it is.
- One name per thing; the popover, editor, and settings use the same words for the same control.
- Rare editing, so recoverable editing: changes to a preset must be reversible.

## Accessibility & Inclusion

Follow the macOS Human Interface Guidelines closely. Respect the system text-size setting and give every control a VoiceOver name and value; these are requirements. Today most text is fixed point size and several icon-only buttons have no accessible name (see `.impeccable/critique/`).
