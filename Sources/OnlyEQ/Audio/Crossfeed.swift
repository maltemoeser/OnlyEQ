import Foundation

/// Bauer-style headphone crossfeed. Each channel receives a low-passed,
/// attenuated, slightly delayed copy of the other channel and gives up the
/// same amount of its own bass, so centred content passes at unity while
/// hard-panned bass is shared between both ears.
struct CrossfeedParameters {
    var feed: Float = 0                // linear cross level; 0 disables the stage
    var lowPassCoefficient: Float = 0  // first-order low-pass: y += a * (x - y)
    var delaySamples: Int = 0

    static let cutoffHz = 700.0
    static let delaySeconds = 0.0003

    static func make(levelDB: Double, sampleRate: Double) -> CrossfeedParameters {
        CrossfeedParameters(
            feed: Float(pow(10, levelDB / 20)),
            lowPassCoefficient: Float(1 - exp(-2 * .pi * cutoffHz / sampleRate)),
            delaySamples: min(Int((delaySeconds * sampleRate).rounded()), CrossfeedState.maxDelay - 1)
        )
    }
}

/// Render-thread state. Storage is allocated once at construction so the
/// realtime path never touches the heap.
struct CrossfeedState {
    static let maxDelay = 128  // 0.3 ms at up to 384 kHz

    private var delayedLeft = [Float](repeating: 0, count: maxDelay)
    private var delayedRight = [Float](repeating: 0, count: maxDelay)
    private var writeIndex = 0
    private var lowLeft: Float = 0
    private var lowRight: Float = 0

    mutating func reset() {
        for i in delayedLeft.indices {
            delayedLeft[i] = 0
            delayedRight[i] = 0
        }
        writeIndex = 0
        lowLeft = 0
        lowRight = 0
    }

    @inline(__always)
    mutating func process(left: inout Float, right: inout Float, _ p: CrossfeedParameters) {
        var readIndex = writeIndex - p.delaySamples
        if readIndex < 0 { readIndex += Self.maxDelay }
        let pastLeft = delayedLeft[readIndex]
        let pastRight = delayedRight[readIndex]
        delayedLeft[writeIndex] = left
        delayedRight[writeIndex] = right
        writeIndex += 1
        if writeIndex == Self.maxDelay { writeIndex = 0 }

        // Both the cross term and the bass compensation use the delayed,
        // low-passed signal, so L == R cancels exactly.
        lowLeft += p.lowPassCoefficient * (pastLeft - lowLeft)
        lowRight += p.lowPassCoefficient * (pastRight - lowRight)
        left += p.feed * (lowRight - lowLeft)
        right += p.feed * (lowLeft - lowRight)
    }
}
