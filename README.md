<p align="center">
  <img src="docs/screenshots/popover.png" width="460" alt="OnlyEQ menu bar popover">
</p>

# OnlyEQ

System-wide parametric EQ for macOS. Lives in the menu bar. No virtual audio drivers.

OnlyEQ uses the process tap API Apple added in macOS 14.4: it taps the system output mix, runs it through biquad filters, and plays the result back to your output device. Nothing to install, no password, no coreaudiod restarts, and your volume keys keep working. It adds about 10 ms of latency at the default 256-frame buffer, fine for music and video. Settings lets you pick 128 to 1024 frames; for a DAW, add the DAW to the exclude list instead.

This is a fork of [zollans/OnlyEQ](https://github.com/zollans/OnlyEQ), which built the tap engine, the importer, and the editor this fork starts from. [What this fork changes](#what-this-fork-changes) lists the additions. Releases and updates come from this repository, not from upstream.

## Install

Requires macOS 14.4 or newer.

1. Download `OnlyEQ.app.zip` from the [latest release](https://github.com/maltemoeser/OnlyEQ/releases/latest) and move `OnlyEQ.app` to `/Applications`.
2. Open it. macOS blocks it the first time, because the app is signed but not notarized (there is no paid developer account behind it). Go to System Settings › Privacy & Security and click Open Anyway.
3. Allow System Audio Recording when asked. That permission is the tap. macOS shows the purple recording indicator while EQ is active; audio never leaves your machine.

Or build from source. It takes about a minute and needs only the Xcode Command Line Tools:

```sh
git clone https://github.com/maltemoeser/OnlyEQ && cd OnlyEQ
./scripts/build-app.sh release && cp -R build/OnlyEQ.app /Applications/
```

After that, OnlyEQ checks for signed updates and installs them in the background. See [RELEASING.md](RELEASING.md) for how releases are built.

## What it does

<p align="center">
  <img src="docs/screenshots/editor.png" width="760" alt="OnlyEQ parametric editor">
</p>

- **Parametric EQ with a draggable curve.** Peak, shelves, high and low pass, notch, band pass, up to 32 bands. Every edit undoes with ⌘Z, arrow keys nudge the selected band, and VoiceOver reads every handle.
- **Live spectrum behind the curve.** The input in grey, the output in blue, so a boost or cut shows against what came in.
- **Bypass and Compare on the plot.** Bypass keeps the preamp and matches loudness to the EQ'd signal, so the comparison is about tone rather than the louder side winning. Compare keeps any curve aside and plays it in place of your edit, level-matched.
- **Adjust bar.** Bass, Treble, Tilt, and Strength sliders sit over an imported profile without editing its bands, for warming up or brightening a correction you otherwise leave alone.
- **Imports every headphone EQ format I could find.** AutoEq, Equalizer APO, peqdb, Wavelet and GraphicEQ, Poweramp, OPRA, Peace, REW, eqMac. Drop a file, paste text, or search the peqdb and AutoEq databases from inside the app.
- **Per-device presets.** Your headphone preset applies when the headphones connect; your speakers keep theirs.
- **Loudness compensation.** Bass and treble rise as you turn the volume down below a reference level you set, so quiet listening keeps its balance.
- **Crossfeed for headphones.** A little of each channel blends into the other, so hard-panned recordings sound less split.
- **Gain staging.** Volume boost up to 200 %, an automatic preamp so boosted EQ does not clip, and a true-peak limiter as a safety net.
- **An exclude list** for apps that handle their own audio, such as DAWs and Zoom.
- **Global hotkeys** for toggling EQ and cycling output devices, launch at login, and signed automatic updates through [Sparkle](https://sparkle-project.org/).

One popover, one editor window, one Settings window.

<p align="center">
  <img src="docs/screenshots/import.png" width="620" alt="OnlyEQ import sheet">
</p>

## What this fork changes

**Listening**

- **Bypass replaces Flat.** Upstream's Flat button and hotkey overwrote the active preset with a flat curve, and the previous preset could only be recovered by importing it again. Both now toggle Bypass, which leaves the preset untouched.
- **Loudness-matched bypass.** Bypass skips only the filter bands and keeps the preamp, output gain, and limiter. It measures the K-weighted loudness (ITU-R BS.1770) the bands add to whatever is playing, averaged over the last three seconds, and applies that gain to the bypassed signal.
- **Crossfeed** in the Bauer style: a low-pass and a 0.3 ms delay, with the near ear giving up the bass the far ear receives so centred content passes at unity. Settings › Sound offers the three published bs2b settings or a custom amount and cutoff.
- **Loudness compensation** following the ISO 226 equal-loudness contours. The preamp absorbs the boost so nothing clips.
- **Input and output spectrum**, level-aligned so only the EQ's effect shows. Bars show band power, tilted 2 dB per octave so music reads flat, with a 10 ms attack and 400 ms release. Bass reads from a 16384-point FFT and the rest from a 2048-point one, so low bands have resolution without smearing transients above.
- **True-peak limiter.** The detector interpolates 4× between samples (ITU-R BS.1770 Annex 2), so the ceiling holds for the reconstructed waveform. Sample peaks alone can under-read inter-sample peaks by up to 3 dB.
- **Matched biquads.** Filters use Vicanek's matched second-order design instead of the bilinear transform, so peaks and shelves near 20 kHz keep their shape and a preset measures the same at 44.1 kHz and 96 kHz. Shelves use his two-pole shelving fit, which holds within about 0.6 dB even for corner frequencies at or above Nyquist.

**Interface**

- **The popover is the instrument.** The live spectrum fills it, with the preset's response as a thin line over it and a volume fader at its side. Bypass, Crossfeed, and the output device sit under the plot as capsules, then the preset with a checkbox that makes it the device's automatic preset. The panel uses the system menu-bar material, and the menu-bar icon fills while the EQ shapes sound.
- **The editor is a Mac window.** The preset name is the window title, with "Edited" beneath it once the curve differs from the saved preset; the preset list opens from the title. Bypass and Compare are pills on the plot. Bands are rows in two columns, low to high in frequency, so a ten-band preset shows whole. Under them, the Adjust bar and the preamp with a peak meter that also holds the highest peak since the window opened. Settings has its own window (⌘,).
- **Releases from GitHub Actions.** A `v*` tag builds the universal app, signs it with this fork's Sparkle key, and publishes it with its appcast as a GitHub Release.

**Presets and import**

- Applying an imported or searched preset saves it, so it stays in the preset picker.
- Filter lines without a `Gain` term (Equalizer APO, REW, and AutoEq write LP, HP, BP, and notch lines this way) import instead of being dropped.
- An undecodable `presets.json` or `profiles.json` is moved aside as `<name>.corrupt-<timestamp>` instead of being overwritten with an empty file.
- Saving a preset under an existing name keeps the menu checkmark and the next-preset hotkey in sync.

**Fixes**

- The render thread no longer allocates memory when the band count or the filter snapshot changes.
- Excluded apps launched after the tap was created are excluded without waiting for a device change.
- Typed band values are clamped to the canvas range, and a frequency shown as "1.5 kHz" edits as 1500 rather than 1.5 Hz.
- Concurrent online database loads no longer race, and the import sheet cancels stale parse and preview work.
- ⌘A, C, V, X, Z, and W in the editor work on Cyrillic, Greek, and Hebrew keyboard layouts.

## How it works

A muted global process tap silences the original system output. The tap and the real output device are wrapped in a private aggregate device, and an IO callback reads the tapped audio, runs it through preamp, biquad filters, crossfeed, loudness shelves, output gain, and a stereo-linked limiter, then writes it to the device. Filter changes swap in atomically without touching the audio thread.

This is the approach the newer Mac audio tools moved to after macOS 14.4. It avoids the virtual-driver failure modes: Bluetooth devices distorting until reconnect, sample-rate mismatches, apps escaping the EQ because they pin their output device, and the driver breaking on every macOS update.

The trade-offs: the purple recording dot is on while EQ runs, macOS before 14.4 is not supported, and pro-audio apps that do their own low-level routing can misbehave with taps. That is what the exclude list is for.

## Development

Plain SwiftPM with no Xcode project. Sparkle is the sole package dependency.

```sh
swift run OnlyEQ --test                      # self-tests (importer, DSP, UI state)
swift run OnlyEQ --engine-probe              # headless engine check, prints JSON
swift run OnlyEQ --editor-probe              # 15-second editor UI profiling run
swift run OnlyEQ --profile-suggestion-probe  # previews Bluetooth profile discovery
swift run OnlyEQ --menu-panel-probe          # previews the arrowless menu panel
swift run OnlyEQ --screenshots out/          # renders the README screenshots
./scripts/build-app.sh release               # universal release build
```

Tests run inside the binary because the Command Line Tools do not ship XCTest. Diagnostics land in `~/Library/Logs/OnlyEQ.log`.

## Credits

- [zollans/OnlyEQ](https://github.com/zollans/OnlyEQ) is the app this fork builds on: the process-tap engine, the importer, the editor, and the per-device presets are theirs.
- [SoundMax](https://github.com/snap-sites/SoundMax) (and the [SoundMaxx](https://github.com/brimell/SoundMaxx) fork) was upstream's inspiration, a native menu bar EQ for the Mac without the BlackHole dependency.
- The feature set borrows from the apps that got these things right first: [eqMac](https://eqmac.app) (in-app AutoEq browsing), [SoundSource](https://rogueamoeba.com/soundsource/) (quick device switching, per-device behavior), and [FineTune](https://github.com/ronitsingh10/FineTune) (the per-app exclude list).
- Headphone correction data comes from [AutoEq](https://github.com/jaakkopasanen/AutoEq) by Jaakko Pasanen and from [peqdb.com](https://peqdb.com); the in-app browser fetches from both. The presets build on measurements by oratory1990 and the many reviewers whose data those databases aggregate.
- The filter math is Robert Bristow-Johnson's [Audio EQ Cookbook](https://www.w3.org/TR/audio-eq-cookbook/), realised with Martin Vicanek's matched second-order designs.
- The capture approach uses Apple's Core Audio process tap API; [AudioCap](https://github.com/insidegui/AudioCap) by Guilherme Rambo was the best public documentation of how it fits together.
- Import formats were reverse-engineered from public exports and docs of [Equalizer APO](https://sourceforge.net/projects/equalizerapo/), [Wavelet](https://pittvandewitt.github.io/Wavelet/), Poweramp, [Peace](https://sourceforge.net/projects/peace-equalizer-apo-extension/), [REW](https://www.roomeqwizard.com), the [OPRA project](https://github.com/opra-project/OPRA), and eqMac.
- Crossfeed follows Boris Mikhaylov's [bs2b](https://bs2b.sourceforge.net/) and the Bauer stereophonic-to-binaural design.

## License

Public domain, under [The Unlicense](LICENSE). No attribution required.
