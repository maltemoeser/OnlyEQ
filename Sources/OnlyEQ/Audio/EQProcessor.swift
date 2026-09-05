import Foundation
import os.lock

/// Realtime-safe EQ chain: preamp → biquad cascade → crossfeed → output gain → limiter.
///
/// The UI thread rebuilds a `Snapshot` and swaps it in under a lock; the render
/// thread try-locks — if the lock is contended it keeps using the old snapshot
/// for that cycle rather than blocking the audio thread.
final class EQProcessor {
    struct Snapshot {
        var coefficients: [BiquadCoefficients] = []
        /// Zeroed filter history for `channelCapacity` channels, allocated on
        /// the model thread and adopted by the render thread when the band
        /// count changes, so the realtime path never calls malloc.
        var freshStates: [BiquadState] = []
        var preampLinear: Float = 1
        var outputGainLinear: Float = 1
        var limiterEnabled = true
        var limiterCeilingLinear: Float = pow(10, -1.0 / 20)  // -1 dBFS
        var bypassed = false
        /// A/B bypass: the bands are skipped, and the K-weighted loudness the
        /// bands added on recent material is applied as gain instead, so the
        /// comparison is loudness-matched rather than only peak-matched.
        var matchBypassLoudness = false
        var crossfeed = CrossfeedParameters()
    }

    private var snapshot = Snapshot()
    /// Guarded by `lock`. Holds the next snapshot while `hasPending`, and the
    /// retired one afterwards so its storage is released by the next update()
    /// on the model thread rather than freed on the render thread.
    private var pending = Snapshot()
    private var hasPending = false
    private var lock = os_unfair_lock()
    private static let channelCapacity = 8

    // Render-thread state (only touched on the audio thread).
    private var states: [BiquadState] = []  // flattened [channel][band]
    private var stateBandCount = 0
    private var crossfeed = CrossfeedState()
    private var limiterEnvelope: Float = 0
    private var limiterAttack = Float(exp(-1.0 / (0.001 * 48000)))
    private var limiterRelease = Float(exp(-1.0 / (0.080 * 48000)))
    private var truePeak = TruePeakEstimator(channels: EQProcessor.channelCapacity)
    private(set) var sampleRate: Double = 48000

    // Loudness matching for A/B bypass. Mono mixes of the band input and band
    // output are K-weighted (ITU-R BS.1770: 38 Hz high-pass, +4 dB shelf above
    // 1.7 kHz) and averaged over the 3 s short-term window; their ratio is the
    // gain the bands added on what is playing, and bypass applies it.
    private var kWeighting: [BiquadCoefficients] = []
    private var kStatesIn = [BiquadState](repeating: BiquadState(), count: 2)
    private var kStatesOut = [BiquadState](repeating: BiquadState(), count: 2)
    private var inputMeanSquare: Float = 0
    private var outputMeanSquare: Float = 0
    private var meanSquareCoefficient = Float(1 - exp(-1.0 / (3.0 * 48000)))
    private var matchGain: Float = 1
    private var matchSmoothing = Float(1 - exp(-1.0 / (0.050 * 48000)))
    private static let matchGainLimit: Float = 4  // ±12 dB

    /// Peak level (post-chain) for metering; read from any thread.
    private struct MeterState {
        var peak: Float = 0
        var isActive = false
        /// Gain currently applied by loudness-matched bypass, in dB (0 when
        /// the bands are active), so the spectrum view can align the bars.
        var bypassMatchDB: Float = 0
    }
    private let meter = OSAllocatedUnfairLock(initialState: MeterState())

    /// Preamp plus output gain of the latest update, in dB. The spectrum view
    /// subtracts it from the output bars so input and output line up and only
    /// the filter shape shows as a difference.
    private let staticGain = OSAllocatedUnfairLock(initialState: Float(0))
    var staticGainDB: Float { staticGain.withLock { $0 } }
    var bypassMatchDB: Float { meter.withLock { $0.bypassMatchDB } }
    var currentPeak: Float {
        meter.withLock { state in
            let value = state.peak
            state.peak = 0
            return value
        }
    }

    func configure(sampleRate: Double) {
        self.sampleRate = sampleRate
        limiterAttack = Float(exp(-1.0 / (0.001 * sampleRate)))
        limiterRelease = Float(exp(-1.0 / (0.080 * sampleRate)))
        meanSquareCoefficient = Float(1 - exp(-1.0 / (3.0 * sampleRate)))
        matchSmoothing = Float(1 - exp(-1.0 / (0.050 * sampleRate)))
        kWeighting = [
            BiquadCoefficients.make(type: .highPass, frequency: 38.135, gainDB: 0, q: 0.5003, sampleRate: sampleRate),
            BiquadCoefficients.make(type: .highShelf, frequency: 1681.97, gainDB: 3.9998, q: 0.7071752, sampleRate: sampleRate),
        ]
    }

    /// Main/UI thread: the peak accumulator has no consumer while the editor
    /// is hidden, so avoid a cross-thread lock on every render callback.
    func setMeteringActive(_ active: Bool) {
        meter.withLock { state in
            state.isActive = active
            if !active { state.peak = 0 }
        }
    }

    /// Audio thread only. Clear filter and limiter history before the engine
    /// enters its prolonged-silence fast path. Keeping the existing storage
    /// avoids allocating from the realtime callback.
    func resetRenderState() {
        for index in states.indices { states[index] = BiquadState() }
        crossfeed.reset()
        limiterEnvelope = 0
        truePeak.reset()
        for i in kStatesIn.indices { kStatesIn[i] = BiquadState(); kStatesOut[i] = BiquadState() }
        inputMeanSquare = 0
        outputMeanSquare = 0
        matchGain = 1
    }

    /// Called from the UI/model thread whenever parameters change.
    func update(bands: [EQBand], preampDB: Double, outputGainDB: Double = 0,
                limiterEnabled: Bool, limiterCeilingDB: Double, bypassed: Bool,
                matchBypassLoudness: Bool = false,
                crossfeedEnabled: Bool = false, crossfeedLevelDB: Double = -6,
                crossfeedCutoffHz: Double = CrossfeedPreset.chuMoy.cutoffHz) {
        var snap = Snapshot()
        snap.coefficients = bands.filter(\.isEnabled).map {
            BiquadCoefficients.make(type: $0.type, frequency: $0.frequency, gainDB: $0.gain, q: $0.q, sampleRate: sampleRate)
        }
        snap.preampLinear = Float(pow(10, preampDB / 20))
        snap.outputGainLinear = Float(pow(10, outputGainDB / 20))
        staticGain.withLock { $0 = Float(preampDB + outputGainDB) }
        snap.limiterEnabled = limiterEnabled
        snap.limiterCeilingLinear = Float(pow(10, limiterCeilingDB / 20))
        snap.bypassed = bypassed
        snap.matchBypassLoudness = matchBypassLoudness
        if crossfeedEnabled {
            snap.crossfeed = CrossfeedParameters.make(levelDB: crossfeedLevelDB, cutoffHz: crossfeedCutoffHz,
                                                      sampleRate: sampleRate)
        }
        snap.freshStates = Array(repeating: BiquadState(), count: Self.channelCapacity * snap.coefficients.count)
        os_unfair_lock_lock(&lock)
        pending = snap
        hasPending = true
        os_unfair_lock_unlock(&lock)
    }

    /// Process non-interleaved Float32 channel buffers in place. Audio thread only.
    func process(channels: [UnsafeMutablePointer<Float>], frameCount: Int) {
        if os_unfair_lock_trylock(&lock) {
            if hasPending {
                swap(&snapshot, &pending)
                hasPending = false
                if snapshot.coefficients.count != stateBandCount {
                    // Adopt the preallocated history; the old one retires
                    // with the previous snapshot.
                    swap(&states, &snapshot.freshStates)
                    stateBandCount = snapshot.coefficients.count
                    limiterEnvelope = 0
                }
            }
            os_unfair_lock_unlock(&lock)
        }
        let snap = snapshot
        // Bypass skips only the filter bands. The preamp stays so A/B listening
        // is level-matched (a -6 dB preamp compensating +6 dB boosts would
        // otherwise make bypass jump 6 dB louder), and the output gain and
        // limiter stay because on devices without hardware volume the output
        // gain is the volume control.
        let applyEQ = !snap.bypassed
        let applyMatch = snap.bypassed && snap.matchBypassLoudness
        let preampLinear = snap.preampLinear
        let channelScale = 1 / Float(max(channels.count, 1))
        let usesTruePeak = channels.count <= truePeak.channelCapacity

        let channelCount = channels.count
        let bandCount = snap.coefficients.count
        if states.count < channelCount * bandCount {
            // More channels than `channelCapacity`: allocate as a last resort.
            states = Array(repeating: BiquadState(), count: channelCount * bandCount)
        }

        let meteringActive = meter.withLockIfAvailable { $0.isActive } ?? false
        var peak: Float = 0

        // Work through raw buffers so mutating filter state does not trigger an
        // Array copy-on-write uniqueness check for every sample and band.
        channels.withUnsafeBufferPointer { channelBuffers in
            states.withUnsafeMutableBufferPointer { stateBuffer in
                snap.coefficients.withUnsafeBufferPointer { coefficientBuffer in
                    let stateBase = stateBuffer.baseAddress
                    let coefficientBase = coefficientBuffer.baseAddress

                    let applyCrossfeed = channelCount == 2 && snap.crossfeed.feed > 0
                    for frame in 0..<frameCount {
                        var monoIn: Float = 0
                        var monoOut: Float = 0
                        for ch in 0..<channelCount {
                            var sample = channelBuffers[ch][frame] * preampLinear
                            monoIn += sample
                            if applyEQ, bandCount > 0, let stateBase, let coefficientBase {
                                let channelStates = stateBase + ch * bandCount
                                for band in 0..<bandCount {
                                    sample = channelStates[band].process(sample, coefficientBase[band])
                                }
                            }
                            monoOut += sample
                            channelBuffers[ch][frame] = sample
                        }
                        if applyEQ {
                            var weightedIn = monoIn * channelScale
                            var weightedOut = monoOut * channelScale
                            for stage in kWeighting.indices {
                                weightedIn = kStatesIn[stage].process(weightedIn, kWeighting[stage])
                                weightedOut = kStatesOut[stage].process(weightedOut, kWeighting[stage])
                            }
                            inputMeanSquare += meanSquareCoefficient * (weightedIn * weightedIn - inputMeanSquare)
                            outputMeanSquare += meanSquareCoefficient * (weightedOut * weightedOut - outputMeanSquare)
                            let target = inputMeanSquare > 1e-10
                                ? min(max(sqrt(outputMeanSquare / inputMeanSquare), 1 / Self.matchGainLimit), Self.matchGainLimit)
                                : 1
                            matchGain += matchSmoothing * (target - matchGain)
                        } else if applyMatch {
                            for ch in 0..<channelCount { channelBuffers[ch][frame] *= matchGain }
                        }
                        if applyCrossfeed {
                            crossfeed.process(left: &channelBuffers[0][frame], right: &channelBuffers[1][frame], snap.crossfeed)
                        }
                        // Stereo-linked limiter on the loudest true peak across channels.
                        var maxMag: Float = 0
                        for ch in 0..<channelCount {
                            let sample = channelBuffers[ch][frame] * snap.outputGainLinear
                            channelBuffers[ch][frame] = sample
                            maxMag = max(maxMag, usesTruePeak ? truePeak.push(sample, channel: ch) : abs(sample))
                        }
                        if usesTruePeak { truePeak.advance() }
                        if snap.limiterEnabled {
                            let coefficient = maxMag > limiterEnvelope ? limiterAttack : limiterRelease
                            limiterEnvelope = coefficient * limiterEnvelope + (1 - coefficient) * maxMag
                            if limiterEnvelope > snap.limiterCeilingLinear {
                                let gain = snap.limiterCeilingLinear / limiterEnvelope
                                for ch in 0..<channelCount { channelBuffers[ch][frame] *= gain }
                                maxMag *= gain
                            }
                        }
                        if meteringActive { peak = max(peak, maxMag) }
                    }
                }
            }
        }

        let framePeak = peak
        let matchDB: Float = applyMatch ? 20 * log10(matchGain) : 0
        meter.withLockIfAvailable { state in
            state.bypassMatchDB = matchDB
            if state.isActive && meteringActive { state.peak = max(state.peak, framePeak) }
        }
    }
}
