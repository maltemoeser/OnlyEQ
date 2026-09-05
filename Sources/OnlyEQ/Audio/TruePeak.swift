import Foundation

/// Inter-sample peak estimator in the spirit of ITU-R BS.1770 Annex 2: the
/// signal is interpolated 4× with a 12-tap windowed-sinc polyphase filter and
/// the largest magnitude among the sample and its three interpolated
/// neighbours is reported. Sample-peak metering under-reads the reconstructed
/// waveform by up to 3 dB (Nielsen & Lund, AES 23rd Conference, 2003), so a
/// limiter fed by sample peaks does not deliver its ceiling as true peak.
///
/// The estimate is six samples behind the input, which is well inside the
/// limiter's 1 ms attack.
struct TruePeakEstimator {
    static let taps = 12
    /// Three interpolation phases (¼, ½, ¾ of a sample), each `taps` long,
    /// normalized to unity DC gain.
    static let phases: [[Float]] = (1...3).map { phase in
        let d = Double(phase) / 4
        let raw = (0..<taps).map { i -> Double in
            let t = Double(i) - 5 - d
            let sinc = t == 0 ? 1 : sin(.pi * t) / (.pi * t)
            let window = 0.5 * (1 + cos(.pi * t / 6))
            return sinc * window
        }
        let sum = raw.reduce(0, +)
        return raw.map { Float($0 / sum) }
    }

    private var history: [Float]
    private var writeIndex = 0
    /// `phases` flattened so the render loop indexes one array.
    private let flatTaps: [Float] = phases.flatMap { $0 }

    init(channels: Int) {
        history = [Float](repeating: 0, count: channels * Self.taps)
    }

    var channelCapacity: Int { history.count / Self.taps }

    mutating func reset() {
        for i in history.indices { history[i] = 0 }
        writeIndex = 0
    }

    /// Push one sample for `channel` and return the true-peak magnitude
    /// estimate at the interpolation point six samples ago.
    @inline(__always)
    mutating func push(_ sample: Float, channel: Int) -> Float {
        let base = channel * Self.taps
        history[base + writeIndex] = sample
        var peak = abs(history[base + (writeIndex + Self.taps - 6) % Self.taps])
        for phase in 0..<3 {
            var acc: Float = 0
            // Oldest sample first: history is a ring, so index from writeIndex + 1.
            var idx = writeIndex + 1
            let tapBase = phase * Self.taps
            for i in 0..<Self.taps {
                if idx == Self.taps { idx = 0 }
                acc += history[base + idx] * flatTaps[tapBase + i]
                idx += 1
            }
            peak = max(peak, abs(acc))
        }
        return peak
    }

    /// Advance the shared write position after every channel has pushed.
    @inline(__always)
    mutating func advance() {
        writeIndex += 1
        if writeIndex == Self.taps { writeIndex = 0 }
    }
}
