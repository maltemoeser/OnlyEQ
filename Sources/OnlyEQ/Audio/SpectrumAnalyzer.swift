import Foundation
import Accelerate
import os.lock

/// Collects post-EQ samples on the audio thread and computes log-spaced
/// spectrum bars on demand from the UI thread.
final class SpectrumAnalyzer {
    static let barCount = 48
    private static let fftSize = 2048
    private static let analysisReuseInterval = 1.0 / 30.0

    /// Display tilt in dB per octave, pivoted at 1 kHz. Commercial recordings
    /// decay at about 5 dB/octave in power spectral density (Pestana et al.,
    /// AES 135, 2013). Constant-Q bands already absorb the 3 dB/octave of
    /// pink noise, so 2 dB/octave is what makes typical music read flat.
    static let tiltDBPerOctave: Float = 2
    /// Detector time constants on band power: quick attack so transients
    /// register, slow release so the display does not flicker. A 400 ms
    /// release decays about 11 dB/s, between IEC 61672's F and S weightings.
    private static let attackTau = 0.010
    private static let releaseTau = 0.400

    private struct RingState {
        var samples = [Float](repeating: 0, count: SpectrumAnalyzer.fftSize)
        var writeIndex = 0
        var generation: UInt64 = 0
        var isActive = false
    }

    private struct UnsafeChannels: @unchecked Sendable {
        var values: [UnsafeMutablePointer<Float>]
    }

    private let ring = OSAllocatedUnfairLock(initialState: RingState())
    private let fftSetup = vDSP.FFT(log2n: vDSP_Length(log2(Double(SpectrumAnalyzer.fftSize))),
                                    radix: .radix2, ofType: DSPSplitComplex.self)
    private var sampleRate: Double = 48000

    // Scratch buffers reused across `bars()` calls (UI thread only), so the
    // periodic spectrum refresh never allocates.
    private let window: [Float]
    private var timeDomain: [Float]
    private var windowed: [Float]
    private var real: [Float]
    private var imag: [Float]
    private var powers: [Float]
    private var barsOut: [Float]
    private var smoothedPower: [Float]
    private let tilt: [Float]
    private var binRanges: [(lo: Int, hi: Int)] = []
    private var analyzedGeneration: UInt64 = .max
    private var lastAnalysisTime: TimeInterval = 0

    init() {
        let n = Self.fftSize
        var hann = [Float](repeating: 0, count: n)
        vDSP_hann_window(&hann, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        window = hann
        timeDomain = [Float](repeating: 0, count: n)
        windowed = [Float](repeating: 0, count: n)
        real = [Float](repeating: 0, count: n / 2)
        imag = [Float](repeating: 0, count: n / 2)
        powers = [Float](repeating: 0, count: n / 2)
        barsOut = [Float](repeating: 0, count: Self.barCount)
        smoothedPower = [Float](repeating: 0, count: Self.barCount)
        tilt = (0..<Self.barCount).map { bar in
            Self.tiltDBPerOctave * log2(Self.barCenterHz(bar) / 1000)
        }
        rebuildBinRanges()
    }

    func configure(sampleRate: Double) {
        self.sampleRate = sampleRate
        rebuildBinRanges()
    }

    /// Main/UI thread: enable collection only while at least one spectrum view
    /// is visible. This leaves the audio callback with a single failed try-lock
    /// and no per-sample mixdown work while the UI is hidden.
    func setActive(_ active: Bool) {
        let changed = ring.withLock { state -> Bool in
            guard state.isActive != active else { return false }
            state.isActive = active
            if active {
                state.samples.withUnsafeMutableBufferPointer { samples in
                    samples.update(repeating: 0)
                }
                state.writeIndex = 0
                state.generation &+= 1
            }
            return true
        }
        if changed {
            barsOut.withUnsafeMutableBufferPointer { bars in
                bars.initialize(repeating: 0)
            }
            smoothedPower.withUnsafeMutableBufferPointer { levels in
                levels.initialize(repeating: 0)
            }
            analyzedGeneration = .max
            lastAnalysisTime = 0
        }
    }

    /// Audio thread: push a mono mixdown of the processed buffer.
    func push(channels: [UnsafeMutablePointer<Float>], frameCount: Int) {
        guard !channels.isEmpty else { return }
        let unsafeChannels = UnsafeChannels(values: channels)
        ring.withLockIfAvailable { state in
            guard state.isActive else { return }
            var idx = state.writeIndex
            let scale = 1.0 / Float(unsafeChannels.values.count)
            state.samples.withUnsafeMutableBufferPointer { samples in
                guard let destinationBase = samples.baseAddress,
                      let firstChannel = unsafeChannels.values.first else { return }
                var sourceOffset = 0
                var scale = scale
                while sourceOffset < frameCount {
                    let count = min(frameCount - sourceOffset, Self.fftSize - idx)
                    let destination = destinationBase + idx
                    vDSP_vsmul(firstChannel + sourceOffset, 1, &scale,
                               destination, 1, vDSP_Length(count))
                    for channel in unsafeChannels.values.dropFirst() {
                        vDSP_vsma(channel + sourceOffset, 1, &scale,
                                  destination, 1, destination, 1, vDSP_Length(count))
                    }
                    sourceOffset += count
                    idx += count
                    if idx == Self.fftSize { idx = 0 }
                }
            }
            state.writeIndex = idx
            state.generation &+= 1
        }
    }

    /// UI thread: 0…1 levels for `barCount` log-spaced bands, 20 Hz – 20 kHz.
    /// Each bar is the band's power (a full-scale sine reads 0 dBFS), tilted
    /// by `tiltDBPerOctave`, run through the attack/release detector, and
    /// mapped -60…0 dB → 0…1. `now` is injectable for tests.
    func bars(now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> [Float] {
        guard let fftSetup else { return [] }

        // Popover and editor consumers can fire in the same display cycle. A
        // short global cache lets both share one 30 Hz FFT result while their
        // presentation layers animate independently.
        if now - lastAnalysisTime < Self.analysisReuseInterval { return barsOut }

        let n = Self.fftSize
        let generation = ring.withLock { state -> UInt64 in
            let generation = state.generation
            guard generation != analyzedGeneration else { return generation }

            // Rotate the ring into chronological order before windowing. This
            // also avoids the discontinuity that used to move through the FFT
            // input as writeIndex wrapped.
            state.samples.withUnsafeBufferPointer { source in
                timeDomain.withUnsafeMutableBufferPointer { destination in
                    guard let src = source.baseAddress, let dst = destination.baseAddress else { return }
                    let tailCount = n - state.writeIndex
                    dst.update(from: src + state.writeIndex, count: tailCount)
                    if state.writeIndex > 0 {
                        (dst + tailCount).update(from: src, count: state.writeIndex)
                    }
                }
            }
            return generation
        }
        // Unchanged ring: skip the FFT but keep the detector releasing toward
        // the last measured powers so the display settles instead of freezing.
        if generation != analyzedGeneration {
            vDSP_vmul(timeDomain, 1, window, 1, &windowed, 1, vDSP_Length(n))

            real.withUnsafeMutableBufferPointer { rp in
                imag.withUnsafeMutableBufferPointer { ip in
                    var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                    windowed.withUnsafeBytes { raw in
                        raw.baseAddress!.assumingMemoryBound(to: DSPComplex.self).withMemoryRebound(to: DSPComplex.self, capacity: n / 2) { complexPtr in
                            vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(n / 2))
                        }
                    }
                    fftSetup.forward(input: split, output: &split)
                    vDSP_zvmags(&split, 1, &powers, 1, vDSP_Length(n / 2))
                }
            }
        }

        // The ring starts cleared on activation, so the first analysis snaps.
        let elapsed = lastAnalysisTime == 0 ? 10.0 : min(now - lastAnalysisTime, 10.0)
        let attack = Float(1 - exp(-elapsed / Self.attackTau))
        let release = Float(1 - exp(-elapsed / Self.releaseTau))
        // With the normalized Hann window and vDSP's real-FFT scaling, the
        // summed bin power over a band divided by n² is the band's mean-square
        // times two, so a full-scale sine lands at 0 dBFS.
        let powerScale = 1 / (Float(n) * Float(n))
        for bar in 0..<Self.barCount {
            let range = binRanges[bar]
            var sum: Float = 0
            powers.withUnsafeBufferPointer { p in
                vDSP_sve(p.baseAddress! + range.lo, 1, &sum, vDSP_Length(range.hi - range.lo + 1))
            }
            let power = sum * powerScale
            let previous = smoothedPower[bar]
            let level = previous + (power - previous) * (power > previous ? attack : release)
            smoothedPower[bar] = level
            let db = 10 * log10(max(level, 1e-12)) + tilt[bar]
            barsOut[bar] = min(max((db + 60) / 60, 0), 1)
        }
        analyzedGeneration = generation
        lastAnalysisTime = now
        return barsOut
    }

    /// Geometric centre of a bar's band.
    static func barCenterHz(_ bar: Int) -> Float {
        let logLo = log10(Float(20)), logHi = log10(Float(20000))
        return pow(10, logLo + (logHi - logLo) * (Float(bar) + 0.5) / Float(Self.barCount))
    }

    private func rebuildBinRanges() {
        let n = Self.fftSize
        let binWidth = Float(sampleRate) / Float(n)
        let logLo = log10(Float(20)), logHi = log10(Float(20000))
        binRanges = (0..<Self.barCount).map { bar in
            let f0 = pow(10, logLo + (logHi - logLo) * Float(bar) / Float(Self.barCount))
            let f1 = pow(10, logLo + (logHi - logLo) * Float(bar + 1) / Float(Self.barCount))
            let lo = min(n / 2 - 1, max(1, Int(f0 / binWidth)))
            let hi = min(n / 2 - 1, max(lo, Int(f1 / binWidth)))
            return (lo, hi)
        }
    }
}
