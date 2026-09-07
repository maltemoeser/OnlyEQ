import AppKit
import Combine
import CoreAudio
import Foundation

/// Minimal self-test harness (CLT has no XCTest). Run with `swift run OnlyEQ --test`.
enum TestRunner {
    private static var failures: [String] = []
    private static var passed = 0

    private static func expect(_ condition: Bool, _ label: String,
                               file: String = #fileID, line: Int = #line) {
        if condition { passed += 1 }
        else { failures.append("\(label)  (\(file):\(line))") }
    }

    private static func near(_ a: Double, _ b: Double, _ tol: Double = 0.001) -> Bool { abs(a - b) <= tol }

    private static func fixture(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil)
            ?? Bundle.module.resourceURL.map({ $0.appendingPathComponent("Fixtures/\(name)") }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }

    static func run() -> Int32 {
        do {
            try importerTests()
            textEditingShortcutTests()
            dspTests()
            watchdogTests()
            revertTests()
            undoTests()
            windowUndoRoutingTests()
            displayRangeTests()
            bandColorTests()
            bandNudgeTests()
            abUndoTests()
            engineRenderTests()
            appStateTests()
            storeTests()
        } catch {
            failures.append("Uncaught error: \(error)")
        }
        print("\(passed) checks passed, \(failures.count) failed")
        for f in failures { print("  FAIL: \(f)") }
        return failures.isEmpty ? 0 : 1
    }

    private static func textEditingShortcutTests() {
        final class PasteProbeTextView: NSTextView {
            var receivedPaste = false

            override func paste(_ sender: Any?) {
                receivedPaste = true
            }
        }

        let command: NSEvent.ModifierFlags = .command
        expect(AppShortcutMonitor.editingAction(characters: "a", modifiers: command)
               == #selector(NSText.selectAll(_:)), "Command-A maps to Select All")
        expect(AppShortcutMonitor.editingAction(characters: "v", modifiers: command)
               == #selector(NSText.paste(_:)), "Command-V maps to Paste")
        expect(AppShortcutMonitor.editingAction(characters: "z", modifiers: [.command, .shift])
               == Selector(("redo:")), "Command-Shift-Z maps to Redo")
        expect(AppShortcutMonitor.editingAction(characters: "v", modifiers: [.command, .option]) == nil,
               "modified Command-V is not intercepted")
        expect(AppShortcutMonitor.editingAction(characters: "v", modifiers: []) == nil,
               "plain V is not intercepted")
        expect(AppShortcutMonitor.isCloseWindowShortcut(characters: "w", modifiers: command),
               "Command-W maps to Close Window")
        expect(!AppShortcutMonitor.isCloseWindowShortcut(characters: "w", modifiers: [.command, .shift]),
               "modified Command-W is not intercepted")

        let textView = PasteProbeTextView()
        let action = AppShortcutMonitor.editingAction(characters: "v", modifiers: command)
        let delivered = action.map { textView.tryToPerform($0, with: nil) } ?? false
        expect(delivered && textView.receivedPaste, "Paste selector is handled by a text responder")
    }

    private static func importerTests() throws {
        var r = try PresetImporter.importData(fixture("autoeq_parametric.txt"))
        expect(r.detectedFormat == "AutoEq / Equalizer APO parametric", "autoeq format")
        expect(near(r.preset.preampDB, -6.1), "autoeq preamp")
        expect(r.preset.bands.count == 10, "autoeq band count")
        expect(r.preset.bands[0].type == .lowShelf && r.preset.bands[0].frequency == 105, "autoeq LSC band")
        expect(near(r.preset.bands[0].gain, 6.4) && near(r.preset.bands[0].q, 0.70), "autoeq band values")
        expect(r.preset.bands[5].type == .highShelf, "autoeq HSC band")
        expect(near(r.preset.bands[9].q, 5.75), "autoeq high-Q band")

        r = try PresetImporter.importData(fixture("graphiceq.txt"))
        expect(r.detectedFormat == "GraphicEQ (Wavelet)", "graphiceq format")
        expect(r.preset.bands.count == 10, "graphiceq 10 bands")
        expect(r.preset.bands.allSatisfy { $0.type == .peak && $0.q == 1.41 }, "graphiceq peaking Q1.41")
        expect(r.preset.preampDB == 0, "graphiceq no preamp for negative gains")
        if let b125 = r.preset.bands.first(where: { $0.frequency == 125 }) {
            expect(b125.gain < -2.0 && b125.gain > -3.0, "graphiceq interpolation")
        } else { expect(false, "graphiceq 125 Hz band exists") }

        r = try PresetImporter.importData(fixture("poweramp.json"))
        expect(r.detectedFormat == "Poweramp JSON", "poweramp format")
        expect(r.preset.name == "PA-CEQ 3 Parametric", "poweramp name")
        expect(near(r.preset.preampDB, -5.6), "poweramp preamp")
        expect(r.preset.bands.count == 3, "poweramp placeholders dropped")
        expect(r.preset.bands[1].type == .lowShelf && r.preset.bands[2].type == .highShelf, "poweramp types")

        r = try PresetImporter.importData(fixture("opra.json"))
        expect(r.detectedFormat == "OPRA JSON", "opra format")
        expect(near(r.preset.preampDB, -9.3), "opra preamp")
        expect(r.preset.bands.count == 4, "opra band count")
        expect(r.preset.bands[1].type == .lowShelf && r.preset.bands[3].type == .highShelf, "opra types")
        expect(r.preset.bands[3].frequency == 11000, "opra frequency")

        r = try PresetImporter.importData(fixture("eqmac.json"))
        expect(r.detectedFormat == "eqMac JSON", "eqmac format")
        expect(r.preset.name == "Sennheiser HD 650", "eqmac name")
        expect(near(r.preset.preampDB, -6.4), "eqmac preamp")
        expect(r.preset.bands.count == 10 && r.preset.bands[0].frequency == 32, "eqmac bands")
        expect(near(r.preset.bands[0].gain, 6.0), "eqmac gain")

        r = try PresetImporter.importData(fixture("peqdb.json"))
        expect(r.detectedFormat == "peqdb", "peqdb format")
        expect(r.preset.bands.count == 4, "peqdb band count")
        expect(r.preset.bands[0].type == .lowShelf && near(r.preset.bands[0].frequency, 22.2), "peqdb LSC")
        expect(r.preset.bands[3].type == .highShelf, "peqdb HSC")
        expect(near(r.preset.preampDB, -5.7), "peqdb preamp from APO text")

        r = try PresetImporter.importData(fixture("peace.peace"))
        expect(r.detectedFormat == "Peace (Equalizer APO)", "peace format")
        expect(r.preset.bands.count == 4, "peace band count")
        expect(r.preset.bands[0].type == .peak && r.preset.bands[1].type == .lowShelf
               && r.preset.bands[3].type == .highShelf, "peace types")
        expect(near(r.preset.bands[1].gain, 5.5), "peace gain")

        r = try PresetImporter.importData(fixture("rew.txt"))
        expect(r.detectedFormat == "REW filter settings", "rew format")
        expect(r.preset.bands.count == 3, "rew OFF filter dropped")
        expect(r.preset.bands[2].type == .lowShelf && near(r.preset.bands[2].q, 0.707), "rew shelf default Q")
        expect(near(r.preset.bands[0].q, 4.94), "rew Q parsed")

        r = try PresetImporter.importData(fixture("qudelix.txt"))
        expect(r.preset.bands.count == 3, "qudelix padding dropped")
        expect(near(r.preset.preampDB, -5.7), "qudelix preamp")

        r = try PresetImporter.importText("Filter 1: ON PK Fc 1000 Hz Gain -3.0 dB BW Oct 1")
        expect(near(r.preset.bands[0].q, 1.414, 0.01), "BW Oct → Q conversion")

        r = try PresetImporter.importText("""
            Filter 1: ON HP Fc 80 Hz
            Filter 2: ON LPQ Fc 12000 Hz Q 0.707
            Filter 3: ON AP Fc 1000 Hz Q 0.7
            Filter 4: ON PK Fc 1000 Hz Gain -3 dB Q 1
            """)
        expect(r.preset.bands.count == 3, "gain-less filter lines are imported")
        expect(r.preset.bands[0].type == .highPass && r.preset.bands[0].gain == 0, "HP line without gain")
        expect(r.preset.bands[1].type == .lowPass && near(r.preset.bands[1].q, 0.707), "LPQ line keeps Q")
        expect(r.warnings.contains { $0.contains("all-pass") }, "all-pass filter is reported as skipped")

        do {
            _ = try PresetImporter.importText("hello world, no EQ here")
            expect(false, "unrecognized input throws")
        } catch { expect(true, "unrecognized input throws") }

        let original = EQPreset(name: "Round Trip", preampDB: -4.2, bands: [
            EQBand(type: .peak, frequency: 1234, gain: -2.5, q: 2.2),
            EQBand(type: .highShelf, frequency: 9000, gain: 3, q: 0.71),
        ])
        let data = try JSONEncoder().encode(original)
        r = try PresetImporter.importData(data)
        expect(r.detectedFormat == "OnlyEQ preset" && r.preset == original, "native round trip")
    }

    private static func storeTests() {
        // `--test` runs on the main thread (see main.swift), so touching the
        // MainActor-isolated PresetStore directly is safe.
        MainActor.assumeIsolated {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("OnlyEQ-tests-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: dir) }

            let edited = EQPreset(name: "Working", preampDB: -3, bands: [
                EQBand(type: .peak, frequency: 3000, gain: -4, q: 2),
            ])
            let store = PresetStore(directory: dir)
            expect(store.workingPreset(forDevice: "uid-a") == nil, "no working preset for unknown device")
            store.stashWorkingPreset(edited, forDevice: "uid-a")
            expect(store.workingPreset(forDevice: "uid-a") == edited, "working preset stash round trip")
            expect(store.workingPreset(forDevice: "uid-b") == nil, "stash is keyed by device UID")

            let reloaded = PresetStore(directory: dir)
            expect(reloaded.workingPreset(forDevice: "uid-a") == edited, "working preset stash persists to disk")

            let presetsURL = dir.appendingPathComponent("presets.json")
            try? "{not json".data(using: .utf8)!.write(to: presetsURL)
            let corrupt = PresetStore(directory: dir)
            corrupt.save(edited)
            let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
            expect(files.contains { $0.hasPrefix("presets.json.corrupt-") }, "undecodable presets.json is moved aside")
            expect(corrupt.customPresets == [edited], "store recovers to a fresh presets.json")

            let replacement = EQPreset(name: "Working", preampDB: 0, bands: [EQBand(type: .peak, frequency: 500, gain: 2, q: 1)])
            let stored = corrupt.save(replacement)
            expect(stored.id == edited.id && stored.bands == replacement.bands, "saving under an existing name returns the stored id")

            // A device bound to a preset that no longer exists has no usable
            // binding; one bound by a stale ID but a live name still resolves.
            let dead = DeviceProfile(deviceUID: "uid-c", deviceName: "Headphones",
                                     presetID: UUID(), presetName: "Gone")
            expect(corrupt.resolveProfilePreset(dead) == nil, "binding to a deleted preset resolves to nothing")
            let byName = DeviceProfile(deviceUID: "uid-c", deviceName: "Headphones",
                                       presetID: UUID(), presetName: "Working")
            expect(corrupt.resolveProfilePreset(byName)?.id == stored.id, "binding resolves by name when the id is stale")
            expect(corrupt.customPresets.count == 1, "saving under an existing name replaces, not appends")
        }
    }

    private static func loudnessTests() {
        expect(LoudnessCompensation.bands(volumePercent: 100, referencePercent: 100).isEmpty,
               "no loudness compensation at the reference level")
        expect(LoudnessCompensation.bands(volumePercent: 150, referencePercent: 100).isEmpty,
               "no loudness compensation above the reference level")
        // 20 dB below reference: 6 dB bass shelf, 2 dB treble shelf.
        let quiet = LoudnessCompensation.bands(volumePercent: 10, referencePercent: 100)
        expect(quiet.count == 2 && quiet[0].type == .lowShelf && quiet[1].type == .highShelf, "loudness adds two shelves")
        expect(near(quiet[0].gain, 6, 0.05) && near(quiet[1].gain, 2, 0.05), "loudness scales with attenuation")
        let floor = LoudnessCompensation.bands(volumePercent: 1, referencePercent: 200)
        expect(floor[0].gain == 12 && floor[1].gain == 4, "loudness boost is capped")
        // Reference is relative: same ratio, same shelves.
        expect(LoudnessCompensation.bands(volumePercent: 30, referencePercent: 60)
               == LoudnessCompensation.bands(volumePercent: 50, referencePercent: 100), "loudness depends on the ratio to reference")
    }

    private static func crossfeedTests() {
        func run(levelDB: Double, cutoffHz: Double = 700, hz: Double, left: Float, right: Float) -> (left: Float, right: Float) {
            let proc = EQProcessor()
            proc.configure(sampleRate: 48000)
            proc.update(bands: [], preampDB: 0, limiterEnabled: false, limiterCeilingDB: -1, bypassed: false,
                        crossfeedEnabled: true, crossfeedLevelDB: levelDB, crossfeedCutoffHz: cutoffHz)
            var l = (0..<9600).map { Float(sin(Double($0) * 2 * .pi * hz / 48000)) * left }
            var r = (0..<9600).map { Float(sin(Double($0) * 2 * .pi * hz / 48000)) * right }
            l.withUnsafeMutableBufferPointer { lb in
                r.withUnsafeMutableBufferPointer { rb in
                    proc.process(channels: [lb.baseAddress!, rb.baseAddress!], frameCount: 9600)
                }
            }
            return (l[4800...].map(abs).max() ?? 0, r[4800...].map(abs).max() ?? 0)
        }

        let mono = run(levelDB: -6, hz: 100, left: 1, right: 1)
        expect(abs(mono.left - 1) < 0.01 && abs(mono.right - 1) < 0.01, "crossfeed passes centred content at unity")

        // Hard-left 100 Hz at -6 dB feed: the far ear gets ~0.5, the near ear gives up the same.
        let bass = run(levelDB: -6, hz: 100, left: 1, right: 0)
        expect(abs(bass.right - 0.5) < 0.03, "crossfeed feeds bass to the far ear at the set level")
        // The compensation term lags (low-pass phase + 0.3 ms delay), so the
        // near ear sits a little above 0.5 rather than exactly on it.
        expect(bass.left > 0.5 && bass.left < 0.62, "crossfeed compensates the near ear's bass")

        // Hard-left 10 kHz: well above the cutoff, almost nothing crosses over.
        let treble = run(levelDB: -6, hz: 10000, left: 1, right: 0)
        expect(treble.right < 0.06, "crossfeed leaves treble localisation alone")
        expect(treble.left > 0.95, "crossfeed leaves near-ear treble alone")

        // Presets: Meier's lower cutoff crosses less of a 700 Hz tone than the
        // 700 Hz designs do, and the published pairs are what the enum holds.
        let meier = run(levelDB: CrossfeedPreset.meier.levelDB, cutoffHz: CrossfeedPreset.meier.cutoffHz, hz: 700, left: 1, right: 0)
        let natural = run(levelDB: CrossfeedPreset.natural.levelDB, cutoffHz: CrossfeedPreset.natural.cutoffHz, hz: 700, left: 1, right: 0)
        expect(meier.right < natural.right, "Meier preset crosses less than Natural (\(meier.right) vs \(natural.right))")
        expect(CrossfeedPreset.meier.cutoffHz == 650 && CrossfeedPreset.chuMoy.levelDB == -6 && CrossfeedPreset.natural.levelDB == -4.5,
               "crossfeed presets carry the bs2b parameter sets")

        let off = EQProcessor()
        off.configure(sampleRate: 48000)
        off.update(bands: [], preampDB: 0, limiterEnabled: false, limiterCeilingDB: -1, bypassed: false)
        var l = [Float](repeating: 1, count: 256), r = [Float](repeating: 0, count: 256)
        l.withUnsafeMutableBufferPointer { lb in
            r.withUnsafeMutableBufferPointer { rb in
                off.process(channels: [lb.baseAddress!, rb.baseAddress!], frameCount: 256)
            }
        }
        expect(r[255] == 0, "crossfeed is inert when disabled")
    }

    private static func decrampingTests() {
        // The matched design must track the analog prototype across the band,
        // including near Nyquist where the bilinear transform cramps.
        let cases: [(FilterType, Double, Double, Double)] = [
            (.peak, 10000, 6, 1.41), (.peak, 8800, 5.1, 1.42), (.peak, 5400, -2.3, 3), (.peak, 100, -4, 0.5),
            (.highShelf, 8000, 4, 0.71), (.highShelf, 10000, -6, 0.71), (.lowShelf, 105, 6.4, 0.7),
            (.lowPass, 12000, 0, 0.707), (.highPass, 80, 0, 0.707), (.notch, 60, 0, 10), (.bandPass, 1000, 0, 2),
        ]
        var worstEQ = 0.0, worstPass = 0.0, worstBilinearEQ = 0.0
        for (type, fc, gain, q) in cases {
            let fs = 44100.0
            let a = pow(10.0, gain / 40.0)
            let matched = BiquadCoefficients.make(type: type, frequency: fc, gainDB: gain, q: q, sampleRate: fs)
            let bilinear = BiquadCoefficients.makeBilinear(type: type, w0: 2 * .pi * fc / fs, a: a, q: q)
            let isEQ = [.peak, .lowShelf, .highShelf].contains(type)
            for f in EQResponse.logGrid(count: 200) where f < fs * 0.45 {
                let target = 10 * log10(BiquadCoefficients.analogMagnitudeSquared(type: type, ratio: f / fc, a: a, q: q))
                guard target > -30 else { continue }  // skip the stop bands of pass filters
                let error = abs(matched.magnitudeDB(at: f, sampleRate: fs) - target)
                if isEQ {
                    worstEQ = max(worstEQ, error)
                    worstBilinearEQ = max(worstBilinearEQ, abs(bilinear.magnitudeDB(at: f, sampleRate: fs) - target))
                } else {
                    worstPass = max(worstPass, error)
                }
            }
        }
        expect(worstEQ < 0.35, "matched peaks and shelves track the analog target within 0.35 dB (worst \(worstEQ))")
        expect(worstPass < 1, "matched pass, notch and band-pass filters track within 1 dB (worst \(worstPass))")
        expect(worstBilinearEQ > 1, "bilinear peaks and shelves cramp near Nyquist (worst \(worstBilinearEQ))")

        // Shelves at and beyond Nyquist: the pole-matched design used to fall
        // back to bilinear (or worse, fit badly just below its guard), so the
        // very shelves the matched design exists for were cramped.
        var worstShelf = 0.0
        let shelfCases: [(FilterType, Double, Double, Double)] = [
            (.highShelf, 12000, 20, 0.71), (.highShelf, 16800, 12, 0.71), (.highShelf, 21000, 6, 0.71),
            (.lowShelf, 21600, 20, 0.71), (.lowShelf, 23800, 6, 0.71), (.lowShelf, 12000, 12, 0.71),
            (.highShelf, 12000, 6, 1.0), (.highShelf, 10000, 8, 0.5), (.lowShelf, 15000, -9, 1.2),
        ]
        for (type, fc, gain, q) in shelfCases {
            let fs = 44100.0
            let a = pow(10.0, gain / 40.0)
            let coefficients = BiquadCoefficients.make(type: type, frequency: fc, gainDB: gain, q: q, sampleRate: fs)
            for f in EQResponse.logGrid(count: 200) where f < fs * 0.499 {
                let target = 10 * log10(BiquadCoefficients.analogMagnitudeSquared(type: type, ratio: f / fc, a: a, q: q))
                worstShelf = max(worstShelf, abs(coefficients.magnitudeDB(at: f, sampleRate: fs) - target))
            }
        }
        expect(worstShelf < 1, "shelves near and above Nyquist track the analog target within 1 dB (worst \(worstShelf))")
        print("  shelf fit: worst near-Nyquist error \(String(format: "%.3f", worstShelf)) dB")
        print("  decramping: matched worst \(String(format: "%.3f", worstEQ)) dB, bilinear worst \(String(format: "%.2f", worstBilinearEQ)) dB")

        // Sample-rate independence: the same band at 44.1 and 96 kHz agree.
        let c44 = BiquadCoefficients.make(type: .peak, frequency: 10000, gainDB: 6, q: 1.41, sampleRate: 44100)
        let c96 = BiquadCoefficients.make(type: .peak, frequency: 10000, gainDB: 6, q: 1.41, sampleRate: 96000)
        let drift = [5000.0, 8000, 10000, 14000, 18000].map {
            abs(c44.magnitudeDB(at: $0, sampleRate: 44100) - c96.magnitudeDB(at: $0, sampleRate: 96000))
        }.max() ?? 0
        expect(drift < 0.3, "matched 10 kHz peak agrees across sample rates (drift \(drift))")
    }

    private static func dspTests() {
        decrampingTests()
        let c = BiquadCoefficients.make(type: .peak, frequency: 1000, gainDB: 6, q: 1.41, sampleRate: 48000)
        expect(near(c.magnitudeDB(at: 1000, sampleRate: 48000), 6, 0.01), "peak magnitude at Fc")
        expect(near(c.magnitudeDB(at: 20, sampleRate: 48000), 0, 0.1), "peak magnitude at 20 Hz")
        expect(near(c.magnitudeDB(at: 20000, sampleRate: 48000), 0, 0.1), "peak magnitude at 20 kHz")

        expect(near(EQResponse.autoPreamp(bands: [EQBand(type: .peak, frequency: 1000, gain: 5, q: 1.41)]), -5, 0.1),
               "auto preamp for +5 dB peak")
        expect(EQResponse.autoPreamp(bands: [EQBand(type: .peak, frequency: 1000, gain: -5, q: 1.41)]) == 0,
               "auto preamp zero for cuts")

        let gainProc = EQProcessor()
        gainProc.configure(sampleRate: 48000)
        gainProc.update(bands: [], preampDB: -6.02, limiterEnabled: false, limiterCeilingDB: -1, bypassed: false)
        gainProc.setMeteringActive(true)
        var dc = [Float](repeating: 1.0, count: 512)
        dc.withUnsafeMutableBufferPointer { buf in
            gainProc.process(channels: [buf.baseAddress!], frameCount: 512)
        }
        expect(abs(dc[100] - 0.5) < 0.01, "processor applies preamp gain")
        // The meter reads true peak, and the step from silence to DC
        // reconstructs with a little overshoot.
        let meterPeak = gainProc.currentPeak
        expect(meterPeak > 0.49 && meterPeak < 0.58, "active peak meter reports processed level (\(meterPeak))")
        expect(gainProc.currentPeak == 0, "reading peak meter resets it")

        gainProc.setMeteringActive(false)
        dc.withUnsafeMutableBufferPointer { buf in
            gainProc.process(channels: [buf.baseAddress!], frameCount: 512)
        }
        expect(gainProc.currentPeak == 0, "inactive peak meter does not accumulate")

        let filterProc = EQProcessor()
        filterProc.configure(sampleRate: 48000)
        filterProc.update(bands: [EQBand(type: .peak, frequency: 1000, gain: 6, q: 1.41)],
                          preampDB: 0, limiterEnabled: false, limiterCeilingDB: -1, bypassed: false)
        var filteredSine = (0..<4800).map { Float(0.1 * sin(Double($0) * 2 * .pi * 1000 / 48000)) }
        filteredSine.withUnsafeMutableBufferPointer { buffer in
            filterProc.process(channels: [buffer.baseAddress!], frameCount: buffer.count)
        }
        let filteredPeak = filteredSine[2400...].map(abs).max() ?? 0
        expect(abs(filteredPeak - 0.2) < 0.01, "processor applies biquad gain at center frequency")

        // A same-topology update (gain tweak) must keep the filter history:
        // continuing the sine without a discontinuity stays at the new level.
        filterProc.update(bands: [EQBand(type: .peak, frequency: 1000, gain: 6.1, q: 1.41)],
                          preampDB: 0, limiterEnabled: false, limiterCeilingDB: -1, bypassed: false)
        var continued = (4800..<9600).map { Float(0.1 * sin(Double($0) * 2 * .pi * 1000 / 48000)) }
        continued.withUnsafeMutableBufferPointer { buffer in
            filterProc.process(channels: [buffer.baseAddress!], frameCount: buffer.count)
        }
        let continuedPeak = continued[..<480].map(abs).max() ?? 0
        expect(abs(continuedPeak - 0.2) < 0.02, "same-topology update keeps filter history")

        // A band-count change adopts fresh, zeroed history sized for the new topology.
        filterProc.update(bands: [EQBand(type: .peak, frequency: 1000, gain: 6, q: 1.41),
                                  EQBand(type: .peak, frequency: 2000, gain: 0, q: 1.41)],
                          preampDB: 0, limiterEnabled: false, limiterCeilingDB: -1, bypassed: false)
        var twoBand = (0..<4800).map { Float(0.1 * sin(Double($0) * 2 * .pi * 1000 / 48000)) }
        twoBand.withUnsafeMutableBufferPointer { buffer in
            filterProc.process(channels: [buffer.baseAddress!], frameCount: buffer.count)
        }
        let twoBandPeak = twoBand[2400...].map(abs).max() ?? 0
        expect(abs(twoBandPeak - 0.2) < 0.01, "band-count change keeps processing correctly")

        let bypassProc = EQProcessor()
        bypassProc.configure(sampleRate: 48000)
        bypassProc.update(bands: [EQBand(type: .peak, frequency: 1000, gain: 6, q: 1.41)],
                          preampDB: -6, outputGainDB: -6.02, limiterEnabled: false, limiterCeilingDB: -1, bypassed: true)
        var bypassed = [Float](repeating: 1.0, count: 512)
        bypassed.withUnsafeMutableBufferPointer { buf in
            bypassProc.process(channels: [buf.baseAddress!], frameCount: 512)
        }
        // -6 dB preamp and -6.02 dB output gain both stay: 1.0 → 0.25.
        expect(abs(bypassed[100] - 0.25) < 0.01, "bypass keeps preamp and output gain, skips bands only")

        crossfeedTests()
        loudnessTests()

        let limProc = EQProcessor()
        limProc.configure(sampleRate: 48000)
        limProc.update(bands: [], preampDB: 12, limiterEnabled: true, limiterCeilingDB: -1, bypassed: false)
        var sine = (0..<4800).map { Float(sin(Double($0) * 2 * .pi * 440 / 48000)) }
        sine.withUnsafeMutableBufferPointer { buf in
            limProc.process(channels: [buf.baseAddress!], frameCount: 4800)
        }
        let ceiling = pow(10, Float(-1.0) / 20) * 1.05
        expect(sine[2400...].map(abs).max()! <= ceiling, "limiter caps output at ceiling")

        // True peak: a sine at fs/4 sampled at 45° has sample peaks of 0.707
        // but a reconstructed peak of 1.0. The estimator must see it, and the
        // limiter must act on it rather than on the samples.
        var estimator = TruePeakEstimator(channels: 1)
        var estimate: Float = 0
        for n in 0..<200 {
            estimate = max(estimate, estimator.push(Float(sin(Double(n) * .pi / 2 + .pi / 4)), channel: 0))
            estimator.advance()
        }
        expect(estimate > 0.98 && estimate < 1.02, "true-peak estimator reconstructs inter-sample peak (\(estimate))")
        let tpProc = EQProcessor()
        tpProc.configure(sampleRate: 48000)
        tpProc.update(bands: [], preampDB: 0, limiterEnabled: true, limiterCeilingDB: -1, bypassed: false)
        var quarter = (0..<4800).map { Float(sin(Double($0) * .pi / 2 + .pi / 4)) }
        quarter.withUnsafeMutableBufferPointer { buf in
            tpProc.process(channels: [buf.baseAddress!], frameCount: 4800)
        }
        let samplePeak = quarter[2400...].map(abs).max()!
        expect(samplePeak < 0.707 * 0.9, "limiter holds true peak at the ceiling, so sample peaks sit below it (\(samplePeak))")

        // Loudness-matched bypass: +6 dB peak at 1 kHz with a -6 dB preamp is
        // unity on a 1 kHz tone; plain bypass would be -6 dB, matched bypass
        // measures the bands' gain and gives it back.
        let matchProc = EQProcessor()
        matchProc.configure(sampleRate: 48000)
        let matchBands = [EQBand(type: .peak, frequency: 1000, gain: 6, q: 1.41)]
        matchProc.update(bands: matchBands, preampDB: -6, limiterEnabled: false, limiterCeilingDB: -1, bypassed: false)
        var learn = (0..<(48000 * 6)).map { Float(0.5 * sin(Double($0) * 2 * .pi * 1000 / 48000)) }
        learn.withUnsafeMutableBufferPointer { buf in
            matchProc.process(channels: [buf.baseAddress!], frameCount: buf.count)
        }
        matchProc.update(bands: matchBands, preampDB: -6, limiterEnabled: false, limiterCeilingDB: -1,
                         bypassed: true, matchBypassLoudness: true)
        var ab = (0..<9600).map { Float(0.5 * sin(Double($0) * 2 * .pi * 1000 / 48000)) }
        ab.withUnsafeMutableBufferPointer { buf in
            matchProc.process(channels: [buf.baseAddress!], frameCount: buf.count)
        }
        let matchedPeak = ab[4800...].map(abs).max()!
        expect(abs(matchedPeak - 0.5) < 0.03, "loudness-matched bypass restores the bands' level (\(matchedPeak))")
        expect(abs(matchProc.bypassMatchDB - 6) < 0.5, "bypass match gain is published for spectrum alignment (\(matchProc.bypassMatchDB))")
        matchProc.update(bands: matchBands, preampDB: -6, limiterEnabled: false, limiterCeilingDB: -1, bypassed: true)
        ab.withUnsafeMutableBufferPointer { buf in
            matchProc.process(channels: [buf.baseAddress!], frameCount: buf.count)
        }
        expect(abs(ab[4800...].map(abs).max()! - 0.25) < 0.02, "plain bypass (EQ off) applies no match gain")

        let alignProc = EQProcessor()
        alignProc.configure(sampleRate: 48000)
        alignProc.update(bands: [], preampDB: -6, outputGainDB: -2, limiterEnabled: false,
                         limiterCeilingDB: -1, bypassed: false)
        expect(abs(alignProc.staticGainDB + 8) < 1e-4, "processor reports preamp plus output gain for spectrum alignment")

        let analyzer = SpectrumAnalyzer()
        analyzer.configure(sampleRate: 48000)
        analyzer.setActive(true)
        let exactBinFrequency = 42.0 * 48000 / 2048
        var tone = (0..<2048).map { Float(sin(Double($0) * 2 * .pi * exactBinFrequency / 48000)) }
        tone.withUnsafeMutableBufferPointer { buffer in
            analyzer.push(channels: [buffer.baseAddress!], frameCount: buffer.count)
        }
        let t0: TimeInterval = 100
        let bars = analyzer.bars(now: t0)
        let dominantBar = bars.indices.max(by: { bars[$0] < bars[$1] })
        expect(bars.count == SpectrumAnalyzer.barCount, "spectrum emits configured bar count")
        expect((26...28).contains(dominantBar ?? -1), "spectrum places 1 kHz tone in expected log band")
        expect(bars.max() ?? 0 > 0.98, "full-scale sine reads 0 dBFS after window and FFT calibration")
        expect(abs(SpectrumAnalyzer.tiltDBPerOctave * log2(SpectrumAnalyzer.barCenterHz(27) / 1000)) < 0.5,
               "tilt pivots at 1 kHz")
        let tiltTop = SpectrumAnalyzer.tiltDBPerOctave * log2(SpectrumAnalyzer.barCenterHz(47) / 1000)
        expect(tiltTop > 8 && tiltTop < 9, "top bar (about 18.6 kHz) is tilted up by 2 dB per octave above 1 kHz")

        var silence = [Float](repeating: 0, count: 2048)
        silence.withUnsafeMutableBufferPointer { buffer in
            analyzer.push(channels: [buffer.baseAddress!], frameCount: buffer.count)
        }
        let dominant = dominantBar ?? 27
        let shortly = analyzer.bars(now: t0 + 0.05)[dominant]
        expect(shortly > 0.95 && shortly < bars[dominant],
               "silence after a tone releases slowly (\(shortly))")
        expect(analyzer.bars(now: t0 + 8)[dominant] < 0.01, "silence fully decays within seconds")

        analyzer.setActive(false)
        analyzer.setActive(true)
        expect(analyzer.bars().allSatisfy { $0 == 0 }, "reactivating spectrum starts with a cleared ring")

        // Bass resolution: a 50 Hz tone must land in its own bar, not smear
        // across every bar that shares the short FFT's first few bins.
        var bass = (0..<16384).map { Float(sin(Double($0) * 2 * .pi * 50 / 48000)) }
        bass.withUnsafeMutableBufferPointer { buffer in
            analyzer.push(channels: [buffer.baseAddress!], frameCount: buffer.count)
        }
        let bassBars = analyzer.bars(now: ProcessInfo.processInfo.systemUptime + 20)
        let bassBar = bassBars.indices.max(by: { bassBars[$0] < bassBars[$1] }) ?? -1
        expect(bassBar == 6, "50 Hz tone lands in bar 6 (\(bassBar))")
        let expectedBass = (SpectrumAnalyzer.tiltDBPerOctave * log2(SpectrumAnalyzer.barCenterHz(6) / 1000) + 60) / 60
        expect(abs(bassBars[6] - expectedBass) < 0.02, "50 Hz tone reads 0 dBFS before tilt (\(bassBars[6]) vs \(expectedBass))")
        expect(bassBars[4] < bassBars[6] - 0.3 && bassBars[8] < bassBars[6] - 0.3,
               "bars two steps away from a 50 Hz tone are at least 18 dB down")

        // Bluetooth device-name cleanup and deterministic catalog ranking.
        expect(HeadphoneNameMatcher.searchQuery(for: "Aaron’s WH-1000XM5 Stereo") == "WH-1000XM5",
               "headphone matcher strips owner and Bluetooth noise")
        expect(HeadphoneNameMatcher.searchQuery(for: "LE_AirPods Pro") == "AirPods Pro",
               "headphone matcher strips Bluetooth LE prefix")
        expect(HeadphoneNameMatcher.score(query: "WH-1000XM5", candidate: "Sony WH-1000XM5")
               > HeadphoneNameMatcher.score(query: "WH-1000XM5", candidate: "Sony WH-1000XM4"),
               "headphone matcher prioritizes exact model number")
    }

    /// Revert returns the working preset to its stored version and is only
    /// offered while the two differ.
    private static func revertTests() {
        MainActor.assumeIsolated {
            AppState.screenshotMode = true  // no engine, no persistence
            let state = AppState.shared
            let saved = state.store.save(EQPreset(
                name: "Revert Test",
                bands: [EQBand(type: .peak, frequency: 1000, gain: 3, q: 1)]))
            state.apply(saved)
            expect(!state.presetIsModified, "freshly applied preset is not modified")
            state.preset.bands[0].gain = 6
            expect(state.presetIsModified, "edited band marks preset modified")
            state.revertPreset()
            expect(state.preset.bands[0].gain == 3, "revert restores the stored band gain")
            expect(state.preset.id == saved.id, "revert keeps the preset id")
            state.store.delete(saved)
            state.apply(.flat)
            expect(!state.presetIsModified, "built-in preset with no edits is not modified")
        }
    }

    /// Preset edits register with an undo manager one step per user action; a
    /// drag registers once at its end; a no-op change registers nothing.
    private static func undoTests() {
        MainActor.assumeIsolated {
            AppState.screenshotMode = true  // no engine, no persistence
            let state = AppState.shared
            let undo = UndoManager()
            undo.groupsByEvent = false  // no run loop here; group by hand

            state.apply(EQPreset(name: "Undo Test",
                                 bands: [EQBand(type: .peak, frequency: 1000, gain: 3, q: 1)]))
            let original = state.preset

            undo.beginUndoGrouping()
            state.recordingUndo("Add Band", undo) {
                state.preset.bands.append(EQBand(type: .peak, frequency: 2000, gain: -2, q: 2))
            }
            undo.endUndoGrouping()
            expect(state.preset.bands.count == 2, "add band appends")
            expect(undo.canUndo, "add band registers an undo step")
            expect(undo.undoActionName == "Add Band", "undo step carries the action name")

            undo.undo()
            expect(state.preset == original, "undo restores the preset before the add")
            expect(undo.canRedo, "undo leaves a redo step")
            undo.redo()
            expect(state.preset.bands.count == 2, "redo re-adds the band")

            // No group is opened here: an unchanged preset must register nothing.
            state.recordingUndo("Edit Band", undo) { state.preset.bands[0].gain = 3 }
            expect(undo.undoActionName == "Add Band", "a change that leaves the preset equal registers nothing")

            // A drag: many mutations, one snapshot registered at the end.
            let beforeDrag = state.preset
            for step in 1...20 { state.preset.bands[0].gain = 3 + Double(step) * 0.1 }
            undo.beginUndoGrouping()
            state.registerUndo(restoring: beforeDrag, actionName: "Move Band", undoManager: undo)
            undo.endUndoGrouping()
            undo.undo()
            expect(state.preset == beforeDrag, "one undo step reverts the whole drag")

            undo.beginUndoGrouping()
            state.recordingUndo("Delete Band", undo) { state.preset.bands.removeAll { $0.frequency == 2000 } }
            undo.endUndoGrouping()
            expect(state.preset.bands.count == 1, "delete band removes it")
            undo.undo()
            expect(state.preset.bands.count == 2, "undo brings the deleted band back")
            expect(state.preset.bands[1].frequency == 2000, "restored band keeps its values")

            state.recordingUndo("Switch Preset", nil) { state.apply(.flat) }
            expect(state.preset == .flat, "a nil undo manager still applies the change")
        }
    }

    /// The curve display widens in 6 dB steps so imported bands beyond ±12 dB
    /// are drawn where they are.
    private static func displayRangeTests() {
        func preset(_ gains: Double...) -> EQPreset {
            EQPreset(name: "Range", bands: gains.map { EQBand(type: .peak, frequency: 1000, gain: $0, q: 1) })
        }
        expect(preset().displayRangeDB == 12, "empty preset shows ±12 dB")
        expect(preset(3, -11.9).displayRangeDB == 12, "gains within ±12 keep the default range")
        expect(preset(12).displayRangeDB == 12, "a 12 dB band still fits ±12")
        expect(preset(-15.2).displayRangeDB == 18, "a −15 dB band widens to ±18")
        expect(preset(4, 25).displayRangeDB == 30, "a 25 dB band widens to ±30")
    }

    private static func abUndoTests() {
        MainActor.assumeIsolated {
            AppState.screenshotMode = true
            let state = AppState.shared
            let undo = UndoManager()
            undo.groupsByEvent = false
            let a = EQPreset(name: "A", bands: [EQBand(type: .peak, frequency: 1000, gain: 3, q: 1)])
            state.apply(a)
            if state.abSlot != 0 { state.storeABAndSwitch(to: 0) }
            expect(state.abSlot == 0, "test starts in slot A")

            undo.beginUndoGrouping()
            state.storeABAndSwitch(to: 1, undoManager: undo)
            undo.endUndoGrouping()
            expect(state.abSlot == 1, "switching selects slot B")
            expect(state.preset == a, "an empty B starts as a copy of A")
            expect(state.abPreset(inSlot: 0) == a, "A holds the curve that was left")
            expect(undo.undoActionName == "Switch A/B", "the switch is an undo step")

            state.preset.bands[0].gain = -4
            let b = state.preset
            undo.beginUndoGrouping()
            state.storeABAndSwitch(to: 0, undoManager: undo)
            undo.endUndoGrouping()
            expect(state.preset == a, "switching back restores A")

            undo.undo()
            expect(state.abSlot == 1 && state.preset == b, "undo returns to B with its edit")
            undo.redo()
            expect(state.abSlot == 0 && state.preset == a, "redo goes to A again")

            undo.removeAllActions()
            state.storeABAndSwitch(to: 0, undoManager: undo)
            expect(!undo.canUndo, "switching to the active slot registers nothing")

            // Choosing a preset for a slot fills it and switches to it.
            let c = EQPreset(name: "C", bands: [EQBand(type: .peak, frequency: 500, gain: 2, q: 1)])
            undo.beginUndoGrouping()
            state.compare(with: c, inSlot: 1, undoManager: undo)
            undo.endUndoGrouping()
            expect(state.abSlot == 1 && state.preset == c, "choosing a preset for B selects B holding it")
            expect(state.abPreset(inSlot: 0) == a, "A keeps its curve as the reference")
            expect(undo.undoActionName == "Compare with C", "the choice is one named undo step")
            undo.undo()
            expect(state.abSlot == 0 && state.preset == a && state.abPreset(inSlot: 1) == b,
                   "undo restores the slot that was replaced")
            state.preset.bands[0].gain = 9
            expect(state.abSlotIsModified(0) == false, "an unsaved working preset is not marked edited")
        }
    }

    private static func bandNudgeTests() {
        let band = EQBand(type: .peak, frequency: 1000, gain: 0, q: 1)
        expect(band.nudged(.up, fine: false).gain == 0.5, "up nudges gain by 0.5 dB")
        expect(band.nudged(.down, fine: true).gain == -0.1, "option-down nudges gain by 0.1 dB")
        expect(band.nudged(.right, fine: false).frequency == 1059, "right moves a semitone up")
        expect(band.nudged(.left, fine: false).frequency == 944, "left moves a semitone down")
        expect(band.nudged(.right, fine: true).frequency == 1015, "option-right moves a quarter semitone")
        let loud = EQBand(type: .peak, frequency: 19900, gain: 29.8, q: 1)
        expect(loud.nudged(.up, fine: false).gain == 30, "gain clamps at +30 dB")
        expect(loud.nudged(.right, fine: false).frequency == 20000, "frequency clamps at 20 kHz")
        expect(band.nudged(.up, fine: false) != band, "a nudge changes the band value, so it registers undo")
        expect(band.accessibilityValue == "1.00 kilohertz, 0.0 dB, Q 1.00", "spoken value names frequency, gain, and Q")
    }

    /// Band colours are identity, not position: they survive deletes, are
    /// persisted, and never repeat within a preset.
    private static func bandColorTests() {
        func band(_ f: Double) -> EQBand { EQBand(type: .peak, frequency: f, gain: 1, q: 1) }
        var preset = EQPreset(name: "Colours", bands: [band(100), band(200), band(300), band(400)])
        expect(preset.bands.map(\.colorIndex) == [0, 1, 2, 3], "bands are coloured in order when a preset is built")
        preset.bands.remove(at: 1)
        expect(preset.bands.map(\.colorIndex) == [0, 2, 3], "deleting a band keeps the others' colours")
        preset.bands.append(band(500))
        expect(preset.bands.last?.colorIndex == 1, "a new band takes the lowest free colour")
        preset.bands.append(band(600))
        expect(preset.bands.last?.colorIndex == 4, "the next band takes the next free colour")
        expect(preset.bands.map(\.colorIndex) == [0, 2, 3, 1, 4], "no two bands share a colour")
        let plain = band(500)
        expect(preset.bands[3] == plain, "colour is ignored by band equality")
        if let data = try? JSONEncoder().encode(preset),
           let decoded = try? JSONDecoder().decode(EQPreset.self, from: data) {
            expect(decoded.bands.map(\.colorIndex) == [0, 2, 3, 1, 4], "colours survive a save/load round trip")
        } else {
            expect(false, "preset with colours encodes and decodes")
        }
        let legacy = Data("""
        {"id":"6F6C7945-5100-4000-8000-0000000000AA","name":"Old","bands":[{"frequency":100},{"frequency":200}]}
        """.utf8)
        let old = try? JSONDecoder().decode(EQPreset.self, from: legacy)
        expect(old?.bands.map(\.colorIndex) == [0, 1], "presets saved before colours get them on load")
    }

    /// The shortcut monitor sends `undo:` up the responder chain; with no main
    /// menu, the window itself must answer it from its own undo manager.
    private static func windowUndoRoutingTests() {
        final class Flag { var undone = false }
        MainActor.assumeIsolated {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                                  styleMask: [.titled], backing: .buffered, defer: false)
            let flag = Flag()
            window.undoManager?.registerUndo(withTarget: flag) { $0.undone = true }
            expect(window.undoManager?.canUndo == true, "window lazily provides an undo manager")
            expect(window.tryToPerform(Selector(("undo:")), with: nil), "window answers undo: from the responder chain")
            expect(flag.undone, "undo: sent to the window runs the registered step")
        }
    }

    /// Every objectWillChange re-layouts each alive (hidden) window's SwiftUI
    /// tree, so steady-state watchdog ticks must not publish.
    private static func watchdogTests() {
        MainActor.assumeIsolated {
            AppState.screenshotMode = true  // no engine, no persistence
            let state = AppState.shared
            state.engineState = .stopped

            var publishes = 0
            let subscription = state.objectWillChange.sink { _ in publishes += 1 }
            withExtendedLifetime(subscription) {
                state.silenceWatchdogTick()
                state.silenceWatchdogTick()
            }
            expect(publishes == 0, "watchdog ticks publish only on change")
        }
    }

    /// Wraps interleaved sample storage in single-buffer AudioBufferLists and
    /// drives the engine's render callback directly, without Core Audio.
    private static func renderOnce(_ engine: ProcessTapEngine, channels: Int,
                                   input: inout [Float], output: inout [Float]) {
        input.withUnsafeMutableBufferPointer { inBuf in
            output.withUnsafeMutableBufferPointer { outBuf in
                var inputList = AudioBufferList(
                    mNumberBuffers: 1,
                    mBuffers: AudioBuffer(mNumberChannels: UInt32(channels),
                                          mDataByteSize: UInt32(inBuf.count * MemoryLayout<Float>.size),
                                          mData: UnsafeMutableRawPointer(inBuf.baseAddress)))
                var outputList = AudioBufferList(
                    mNumberBuffers: 1,
                    mBuffers: AudioBuffer(mNumberChannels: UInt32(channels),
                                          mDataByteSize: UInt32(outBuf.count * MemoryLayout<Float>.size),
                                          mData: UnsafeMutableRawPointer(outBuf.baseAddress)))
                engine.render(input: &inputList, output: &outputList)
            }
        }
    }

    private static func withAudioBufferList(_ buffers: [AudioBuffer], _ body: (UnsafeMutablePointer<AudioBufferList>) -> Void) {
        let offset = MemoryLayout<AudioBufferList>.offset(of: \.mBuffers)!
        let storage = UnsafeMutableRawPointer.allocate(byteCount: offset + buffers.count * MemoryLayout<AudioBuffer>.size,
                                                        alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { storage.deallocate() }
        let list = storage.assumingMemoryBound(to: AudioBufferList.self)
        list.pointee.mNumberBuffers = UInt32(buffers.count)
        let destination = storage.advanced(by: offset).assumingMemoryBound(to: AudioBuffer.self)
        destination.initialize(from: buffers, count: buffers.count)
        body(list)
    }

    private static func engineRenderTests() {
        let frames = 512, channels = 2

        let stereo = AudioStreamBasicDescription(mSampleRate: 48_000, mFormatID: kAudioFormatLinearPCM,
                                                  mFormatFlags: kAudioFormatFlagIsFloat, mBytesPerPacket: 8,
                                                  mFramesPerPacket: 1, mBytesPerFrame: 8, mChannelsPerFrame: 2,
                                                  mBitsPerChannel: 32, mReserved: 0)
        var physical = stereo
        physical.mChannelsPerFrame = 4
        physical.mBytesPerPacket = 16
        physical.mBytesPerFrame = 16
        var mono = stereo
        mono.mChannelsPerFrame = 1
        mono.mBytesPerPacket = 4
        mono.mBytesPerFrame = 4
        var nonInterleaved = stereo
        nonInterleaved.mFormatFlags |= kAudioFormatFlagIsNonInterleaved
        expect(TapInputSelection.select(tapFormat: stereo, aggregateInputFormats: [physical, stereo], aggregateInputChannels: [4, 2]) == TapInputSelection(bufferIndex: 1, channels: 2), "tap selection finds trailing stereo stream")
        expect(TapInputSelection.select(tapFormat: stereo, aggregateInputFormats: [stereo, physical], aggregateInputChannels: [2, 4]) == TapInputSelection(bufferIndex: 0, channels: 2), "tap selection follows queried stream order")
        expect(TapInputSelection.select(tapFormat: stereo, aggregateInputFormats: [stereo], aggregateInputChannels: [2]) == TapInputSelection(bufferIndex: 0, channels: 2), "tap selection supports built-in stereo")
        expect(TapInputSelection.select(tapFormat: stereo, aggregateInputFormats: [physical, mono, mono], aggregateInputChannels: [4, 1, 1]) == nil, "tap selection rejects adjacent mono candidates")
        expect(TapInputSelection.select(tapFormat: nonInterleaved, aggregateInputFormats: [nonInterleaved], aggregateInputChannels: [2]) == nil, "tap selection rejects non-interleaved tap format")
        expect(TapInputSelection.select(tapFormat: stereo, aggregateInputFormats: [physical], aggregateInputChannels: [4]) == nil, "tap selection rejects missing stereo stream")
        expect(TapInputSelection.select(tapFormat: stereo, aggregateInputFormats: [stereo, stereo], aggregateInputChannels: [2, 2]) == nil, "tap selection rejects ambiguous stereo streams")
        expect(TapInputSelection.select(tapFormat: stereo,
                                        aggregateInputFormats: [stereo, stereo],
                                        aggregateInputChannels: [2, 2],
                                        aggregateInputStartingChannels: [1, 3],
                                        physicalInputChannelCount: 2) == TapInputSelection(bufferIndex: 1, channels: 2),
               "tap selection resolves Scarlett-style matching stereo input at channel boundary")
        expect(TapInputSelection.select(tapFormat: stereo,
                                        aggregateInputFormats: [stereo, stereo],
                                        aggregateInputChannels: [2, 2],
                                        aggregateInputStartingChannels: [3, 1],
                                        physicalInputChannelCount: 2) == TapInputSelection(bufferIndex: 0, channels: 2),
               "tap selection uses channel provenance rather than stream-array order")
        expect(TapInputSelection.select(tapFormat: stereo,
                                        aggregateInputFormats: [stereo, stereo],
                                        aggregateInputChannels: [2, 2],
                                        aggregateInputStartingChannels: [1, 3],
                                        physicalInputChannelCount: 4) == nil,
               "tap selection rejects matching streams without the expected channel boundary")

        let reversedEngine = ProcessTapEngine(preparedInput: TapInputSelection(bufferIndex: 0, channels: 2))
        var reversedTapInput = (0..<frames).flatMap { _ in [Float(0.125), Float(-0.25)] }
        var reversedPhysicalInput = [Float](repeating: 77, count: frames * 4)
        var reversedOutput = [Float](repeating: 0, count: frames * 4)
        reversedTapInput.withUnsafeMutableBufferPointer { tapBuffer in
            reversedPhysicalInput.withUnsafeMutableBufferPointer { physicalBuffer in
                reversedOutput.withUnsafeMutableBufferPointer { outputBuffer in
                    withAudioBufferList([
                        AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(tapBuffer.count * MemoryLayout<Float>.size), mData: tapBuffer.baseAddress),
                        AudioBuffer(mNumberChannels: 4, mDataByteSize: UInt32(physicalBuffer.count * MemoryLayout<Float>.size), mData: physicalBuffer.baseAddress),
                    ]) { input in
                        withAudioBufferList([
                            AudioBuffer(mNumberChannels: 4, mDataByteSize: UInt32(outputBuffer.count * MemoryLayout<Float>.size), mData: outputBuffer.baseAddress),
                        ]) { output in
                            reversedEngine.render(input: input, output: output)
                        }
                    }
                }
            }
        }
        expect((0..<frames).allSatisfy { frame in
            let base = frame * 4
            return reversedOutput[base] == 0.125 && reversedOutput[base + 1] == -0.25
                && reversedOutput[base + 2] == 0.125 && reversedOutput[base + 3] == -0.25
        }, "render consumes selected tap at index 0 before physical stream")
        expect(!reversedOutput.contains(77), "reversed render never outputs physical sentinel")

        let routingEngine = ProcessTapEngine(preparedInput: TapInputSelection(bufferIndex: 1, channels: 2))
        var physicalInput = [Float](repeating: 99, count: frames * 4)
        var tapInput = (0..<frames).flatMap { _ in [Float(0.25), Float(-0.5)] }
        var fourChannelOutput = [Float](repeating: 0, count: frames * 4)
        physicalInput.withUnsafeMutableBufferPointer { physicalBuffer in
            tapInput.withUnsafeMutableBufferPointer { tapBuffer in
                fourChannelOutput.withUnsafeMutableBufferPointer { outputBuffer in
                    withAudioBufferList([
                        AudioBuffer(mNumberChannels: 4, mDataByteSize: UInt32(physicalBuffer.count * MemoryLayout<Float>.size), mData: physicalBuffer.baseAddress),
                        AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(tapBuffer.count * MemoryLayout<Float>.size), mData: tapBuffer.baseAddress),
                    ]) { input in
                        withAudioBufferList([
                            AudioBuffer(mNumberChannels: 4, mDataByteSize: UInt32(outputBuffer.count * MemoryLayout<Float>.size), mData: outputBuffer.baseAddress),
                        ]) { output in
                            routingEngine.render(input: input, output: output)
                        }
                    }
                }
            }
        }
        expect((0..<frames).allSatisfy { frame in
            let base = frame * 4
            return fourChannelOutput[base] == 0.25 && fourChannelOutput[base + 1] == -0.5
                && fourChannelOutput[base + 2] == 0.25 && fourChannelOutput[base + 3] == -0.5
        }, "render routes only selected tap stereo as L/R/L/R")
        expect(!fourChannelOutput.contains(99), "iD4 render never outputs physical sentinel")

        var disabledOutput = [Float](repeating: 0, count: frames * 4)
        tapInput.withUnsafeMutableBufferPointer { tapBuffer in
            disabledOutput.withUnsafeMutableBufferPointer { outputBuffer in
                withAudioBufferList([
                    AudioBuffer(mNumberChannels: 4, mDataByteSize: UInt32(frames * 4 * MemoryLayout<Float>.size), mData: nil),
                    AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(tapBuffer.count * MemoryLayout<Float>.size), mData: tapBuffer.baseAddress),
                ]) { input in
                    withAudioBufferList([
                        AudioBuffer(mNumberChannels: 4, mDataByteSize: UInt32(outputBuffer.count * MemoryLayout<Float>.size), mData: outputBuffer.baseAddress),
                    ]) { output in
                        routingEngine.render(input: input, output: output)
                    }
                }
            }
        }
        expect(disabledOutput == fourChannelOutput, "disabled physical input with null data does not affect selected tap")

        let mismatchEngine = ProcessTapEngine(preparedInput: TapInputSelection(bufferIndex: 1, channels: 2))
        var mismatchOutput = [Float](repeating: 1, count: frames * 4)
        tapInput.withUnsafeMutableBufferPointer { tapBuffer in
            mismatchOutput.withUnsafeMutableBufferPointer { outputBuffer in
                withAudioBufferList([
                    AudioBuffer(mNumberChannels: 4, mDataByteSize: UInt32(frames * 4 * MemoryLayout<Float>.size), mData: nil),
                    AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(tapBuffer.count * MemoryLayout<Float>.size / 2), mData: tapBuffer.baseAddress),
                ]) { input in
                    withAudioBufferList([
                        AudioBuffer(mNumberChannels: 4, mDataByteSize: UInt32(outputBuffer.count * MemoryLayout<Float>.size), mData: outputBuffer.baseAddress),
                    ]) { output in
                        mismatchEngine.render(input: input, output: output)
                    }
                }
            }
        }
        expect(mismatchOutput.allSatisfy { $0 == 0 }, "selected-buffer shape mismatch zeros output")

        let nullEngine = ProcessTapEngine(preparedInput: TapInputSelection(bufferIndex: 1, channels: 2))
        var nullOutput = [Float](repeating: 1, count: frames * 2)
        nullOutput.withUnsafeMutableBufferPointer { outputBuffer in
            withAudioBufferList([
                AudioBuffer(mNumberChannels: 4, mDataByteSize: UInt32(frames * 4 * MemoryLayout<Float>.size), mData: nil),
                AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(frames * 2 * MemoryLayout<Float>.size), mData: nil),
            ]) { input in
                withAudioBufferList([
                    AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(outputBuffer.count * MemoryLayout<Float>.size), mData: outputBuffer.baseAddress),
                ]) { output in
                    nullEngine.render(input: input, output: output)
                }
            }
        }
        expect(nullOutput.allSatisfy { $0 == 0 }, "null selected tap buffer zeros output")

        let missingEngine = ProcessTapEngine(preparedInput: TapInputSelection(bufferIndex: 2, channels: 2))
        var missingOutput = [Float](repeating: 1, count: frames * 2)
        tapInput.withUnsafeMutableBufferPointer { tapBuffer in
            missingOutput.withUnsafeMutableBufferPointer { outputBuffer in
                withAudioBufferList([
                    AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(tapBuffer.count * MemoryLayout<Float>.size), mData: tapBuffer.baseAddress),
                ]) { input in
                    withAudioBufferList([
                        AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(outputBuffer.count * MemoryLayout<Float>.size), mData: outputBuffer.baseAddress),
                    ]) { output in
                        missingEngine.render(input: input, output: output)
                    }
                }
            }
        }
        expect(missingOutput.allSatisfy { $0 == 0 }, "missing selected tap buffer zeros output")

        // Audio starting later in the buffer must still mark the tap as live.
        let lateEngine = ProcessTapEngine()
        var lateInput = [Float](repeating: 0, count: frames * channels)
        for frame in 100..<frames { lateInput[frame * channels] = 0.5 }
        var output = [Float](repeating: 0, count: frames * channels)
        renderOnce(lateEngine, channels: channels, input: &lateInput, output: &output)
        expect(lateEngine.hasReceivedAudio, "render detects audio past the first 64 frames")

        // After a full ring-out window of exact silence the output stays zeroed
        // and the tap is still not considered live.
        let engine = ProcessTapEngine()
        var silence = [Float](repeating: 0, count: frames * channels)
        for _ in 0...(Int(engine.processor.sampleRate) / frames + 1) {
            renderOnce(engine, channels: channels, input: &silence, output: &output)
        }
        var staleOutput = [Float](repeating: 0.7, count: frames * channels)
        renderOnce(engine, channels: channels, input: &silence, output: &staleOutput)
        expect(staleOutput.allSatisfy { $0 == 0 }, "silent input renders silent output after ring-out")
        expect(!engine.hasReceivedAudio, "pure silence never marks the tap as live")

        // Entering the idle path must discard filter/limiter history. Otherwise
        // stale state from a second earlier can leak into the first resumed buffer.
        let stateProcessor = EQProcessor()
        stateProcessor.configure(sampleRate: 48_000)
        stateProcessor.update(
            bands: [EQBand(type: .peak, frequency: 40, gain: 12, q: 20)],
            preampDB: 0, limiterEnabled: true, limiterCeilingDB: -1, bypassed: false
        )
        var primingTone = (0..<512).map { Float(sin(Double($0) * 2 * .pi * 40 / 48_000)) }
        primingTone.withUnsafeMutableBufferPointer {
            stateProcessor.process(channels: [$0.baseAddress!], frameCount: $0.count)
        }
        stateProcessor.resetRenderState()
        var resetSilence = [Float](repeating: 0, count: 512)
        resetSilence.withUnsafeMutableBufferPointer {
            stateProcessor.process(channels: [$0.baseAddress!], frameCount: $0.count)
        }
        expect(resetSilence.allSatisfy { $0 == 0 }, "silence gate clears realtime DSP history")

        // The first non-silent buffer after prolonged silence passes through
        // immediately (no dropout from the idle path).
        var tone = (0..<frames * channels).map {
            Float(0.5 * sin(Double($0 / channels) * 2 * .pi * 440 / 48000))
        }
        var resumed = [Float](repeating: 0, count: frames * channels)
        renderOnce(engine, channels: channels, input: &tone, output: &resumed)
        expect((resumed.map(abs).max() ?? 0) > 0.4, "audio resumes immediately after prolonged silence")
        expect(engine.hasReceivedAudio, "resumed audio marks the tap as live")
    }

    private static func appStateTests() {
        expect(
            BoostSlider.valueAfterScroll(50, deltaY: 1, isPrecise: false, maxPercent: 200) == 52,
            "volume mouse wheel uses two-percent steps"
        )
        expect(
            near(BoostSlider.valueAfterScroll(50, deltaY: 5, isPrecise: true, maxPercent: 200), 51),
            "volume trackpad scroll uses fine-grained steps"
        )
        expect(
            BoostSlider.valueAfterScroll(199, deltaY: 3, isPrecise: false, maxPercent: 200) == 200
                && BoostSlider.valueAfterScroll(1, deltaY: -3, isPrecise: false, maxPercent: 200) == 0,
            "volume scrolling clamps to its configured range"
        )

        expect(
            !AppState.shouldSuggestAudioAccessCheck(
                isEnabled: true,
                engineIsRunning: true,
                hasReceivedAudio: false,
                audioAccessConfirmed: true
            ),
            "confirmed audio access stays valid while playback is idle"
        )
        expect(
            AppState.shouldSuggestAudioAccessCheck(
                isEnabled: true,
                engineIsRunning: true,
                hasReceivedAudio: false,
                audioAccessConfirmed: false
            ),
            "unconfirmed running tap suggests an audio access check"
        )

        expect(
            AppState.topologyAction(
                isEnabled: true, engineIsRunning: true,
                engineTargetID: 41, defaultDeviceID: 52, defaultDeviceIsReady: true
            ) == .rebuild,
            "route rebuild follows engine target after UI device refresh"
        )
        expect(
            AppState.topologyAction(
                isEnabled: true, engineIsRunning: true,
                engineTargetID: 52, defaultDeviceID: 52, defaultDeviceIsReady: true
            ) == .none,
            "route rebuild skips matching engine target"
        )
        expect(
            AppState.topologyAction(
                isEnabled: false, engineIsRunning: true,
                engineTargetID: 41, defaultDeviceID: 52, defaultDeviceIsReady: true
            ) == .none,
            "disabled engine ignores route changes"
        )
        expect(
            AppState.topologyAction(
                isEnabled: true, engineIsRunning: true,
                engineTargetID: 41, defaultDeviceID: nil, defaultDeviceIsReady: false
            ) == .stop,
            "missing output tears down the muted tap"
        )
        expect(
            AppState.topologyAction(
                isEnabled: true, engineIsRunning: false,
                engineTargetID: 0, defaultDeviceID: nil, defaultDeviceIsReady: false
            ) == .none,
            "missing output leaves an already stopped engine alone"
        )
        expect(
            AppState.topologyAction(
                isEnabled: true, engineIsRunning: false,
                engineTargetID: 0, defaultDeviceID: 52, defaultDeviceIsReady: true
            ) == .rebuild,
            "restored output restarts a fail-safe stopped engine"
        )

        MainActor.assumeIsolated {
            AppState.screenshotMode = true  // no engine, no persistence
            let state = AppState.shared
            let savedPreset = state.preset
            let savedAuto = state.autoPreampEnabled
            let savedVolume = state.userVolumePercent
            defer {
                state.preset = savedPreset
                state.autoPreampEnabled = savedAuto
                state.userVolumePercent = savedVolume
            }

            var volumePublishes = 0
            let volumeSubscription = state.objectWillChange.sink { _ in volumePublishes += 1 }
            state.beginVolumeAdjustment()
            state.previewVolumeAdjustment(min(savedVolume + 1, state.maxBoostPercent))
            expect(volumePublishes == 0, "live volume preview does not invalidate the whole app")
            state.userVolumePercent = min(savedVolume + 1, state.maxBoostPercent)
            state.endVolumeAdjustment()
            expect(volumePublishes == 1, "finished volume adjustment publishes once")
            withExtendedLifetime(volumeSubscription) {}

            state.autoPreampEnabled = true
            state.preset = EQPreset(name: "Auto A", bands: [EQBand(type: .peak, frequency: 1000, gain: 5, q: 1.41)])
            expect(near(state.effectivePreampDB, -5, 0.1), "effective preamp follows auto preamp")
            expect(near(state.effectivePreampDB, state.effectivePreampDB), "repeated reads are stable")
            state.preset = EQPreset(name: "Auto B", bands: [EQBand(type: .peak, frequency: 1000, gain: 8, q: 1.41)])
            expect(near(state.effectivePreampDB, -8, 0.1), "effective preamp tracks band edits")

            state.autoPreampEnabled = false
            state.preset.preampDB = -3
            expect(state.effectivePreampDB == -3, "manual preamp used when auto is off")
        }
    }
}
