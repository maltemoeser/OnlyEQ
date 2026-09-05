import Foundation

/// RBJ Audio-EQ-Cookbook biquad coefficients, normalized (a0 == 1).
struct BiquadCoefficients: Equatable {
    // The render path is Float32. Store its coefficients in the same format so
    // every sample does five fused operations instead of five Double→Float
    // conversions per enabled band.
    var b0: Float = 1, b1: Float = 0, b2: Float = 0
    var a1: Float = 0, a2: Float = 0

    static func make(type: FilterType, frequency: Double, gainDB: Double, q rawQ: Double, sampleRate: Double) -> BiquadCoefficients {
        let fc = min(max(frequency, 1), sampleRate * 0.499)
        let q = max(rawQ, 0.025)
        let a = pow(10.0, gainDB / 40.0)
        let w0 = 2.0 * Double.pi * fc / sampleRate
        let matched = makeMatched(type: type, w0: w0, a: a, q: q) ?? makeBilinear(type: type, w0: w0, a: a, q: q)
        guard type == .lowShelf || type == .highShelf,
              let fit = makeShelfFit(type: type, w0: w0, a: a, q: q) else { return matched }
        // Both shelf designs are approximations with different failure modes,
        // so keep whichever tracks the analog prototype more closely here.
        let fitError = fit.worstError(type: type, w0: w0, a: a, q: q)
        let matchedError = matched.worstError(type: type, w0: w0, a: a, q: q)
        return fitError < matchedError ? fit : matched
    }

    /// Largest deviation in dB from the analog prototype over the audio band
    /// up to just below Nyquist, on a 24-point log grid.
    private func worstError(type: FilterType, w0: Double, a: Double, q: Double) -> Double {
        let fs = 2.0  // any rate; w0 fixes the geometry
        let f0 = w0 / (2 * .pi) * fs
        let lo = log10(20.0 / 48000 * fs), hi = log10(0.499 * fs)
        var worst = 0.0
        for i in 0..<24 {
            let f = pow(10, lo + (hi - lo) * Double(i) / 23)
            let target = 10 * log10(Self.analogMagnitudeSquared(type: type, ratio: f / f0, a: a, q: q))
            worst = max(worst, abs(magnitudeDB(at: f, sampleRate: fs) - target))
        }
        return worst
    }

    // MARK: Shelf fit (Vicanek, "Matched Two-Pole Digital Shelving Filters", 2024)

    /// Vicanek's two-pole shelving fit. Unlike `makeMatched`, the poles are
    /// not mapped from the analog filter: numerator and denominator are fitted
    /// jointly from five magnitude conditions (unity at DC, the analog slope
    /// at DC, an exact match at Nyquist, and matches at two interior
    /// frequencies chosen to keep the coefficient square roots real). The paper
    /// is Butterworth-only; the DC-slope condition here generalises it to any
    /// Q, and `make` falls back to the pole-matched design when that fit is
    /// worse. Works for corner frequencies above Nyquist, where the
    /// impulse-invariant poles of `makeMatched` alias.
    private static func makeShelfFit(type: FilterType, w0: Double, a rawA: Double, q: Double) -> BiquadCoefficients? {
        // A low shelf is a high shelf with reciprocal gain, scaled back at the end.
        let a = type == .lowShelf ? 1 / rawA : rawA
        guard abs(a - 1) > 1e-5 else { return nil }
        let fc = w0 / .pi  // in units of Nyquist

        func h(_ f: Double) -> Double {
            analogMagnitudeSquared(type: .highShelf, ratio: f / fc, a: a, q: q)
        }
        let hNy = h(1)
        let f1 = fc / sqrt(0.160 + 1.543 * fc * fc)
        let f2 = fc / sqrt(0.947 + 3.806 * fc * fc)
        let h1 = h(f1), h2 = h(f2)
        let phi1 = pow(sin(.pi / 2 * f1), 2), phi2 = pow(sin(.pi / 2 * f2), 2)
        // Analog |H|² ≈ 1 + (1/Q² − 2)(A − 1/A)(f/fc)² near DC; in φ = sin²(πf/2) ≈ (πf/2)².
        let slope = 4 / (.pi * .pi * fc * fc) * (1 / (q * q) - 2) * (a - 1 / a)

        let d1 = (h1 - 1) * (1 - phi1) - slope * phi1 * (1 - phi1)
        let c11 = -phi1 * (h1 - 1) * (1 - phi1)
        let c12 = phi1 * phi1 * (hNy - h1)
        let d2 = (h2 - 1) * (1 - phi2) - slope * phi2 * (1 - phi2)
        let c21 = -phi2 * (h2 - 1) * (1 - phi2)
        let c22 = phi2 * phi2 * (hNy - h2)
        let det = c11 * c22 - c12 * c21
        guard abs(det) > 1e-18, abs(c12) > 1e-18 else { return nil }
        let alpha1 = (c22 * d1 - c12 * d2) / det
        let A1 = (d1 - c11 * alpha1) / c12
        let B1 = hNy * A1
        let A2 = 0.25 * (alpha1 - A1)
        let B2 = 0.25 * (alpha1 + slope - B1)
        guard A1 >= 0, B1 >= 0 else { return nil }

        let v = 0.5 * (1 + sqrt(A1))
        let w = 0.5 * (1 + sqrt(B1))
        guard v * v + A2 >= 0, w * w + B2 >= 0 else { return nil }
        let a0 = 0.5 * (v + sqrt(v * v + A2))
        let b0u = 0.5 * (w + sqrt(w * w + B2))
        guard a0 > 0, b0u > 0 else { return nil }
        let a1 = (1 - v) / a0
        let a2 = -0.25 * A2 / (a0 * a0)
        let scale = (type == .lowShelf ? rawA * rawA : 1) / a0
        let b0 = b0u * scale
        let b1 = (1 - w) * scale
        let b2 = (-0.25 * B2 / b0u) * scale
        guard [a1, a2, b0, b1, b2].allSatisfy(\.isFinite), abs(a2) < 1, abs(a1) < 1 + a2 else { return nil }
        return BiquadCoefficients(b0: Float(b0), b1: Float(b1), b2: Float(b2), a1: Float(a1), a2: Float(a2))
    }

    // MARK: Matched (decramped) design

    /// Magnitude squared of the RBJ analog prototype at `r` = ω / ω0.
    /// For p(s) = c2 s² + c1 s + c0, |p(jr)|² = (c0 − c2 r²)² + (c1 r)².
    static func analogMagnitudeSquared(type: FilterType, ratio r: Double, a: Double, q: Double) -> Double {
        func mag2(_ c2: Double, _ c1: Double, _ c0: Double) -> Double {
            let re = c0 - c2 * r * r, im = c1 * r
            return re * re + im * im
        }
        switch type {
        case .peak: return mag2(1, a / q, 1) / mag2(1, 1 / (a * q), 1)
        case .lowShelf: return a * a * mag2(1, sqrt(a) / q, a) / mag2(a, sqrt(a) / q, 1)
        case .highShelf: return a * a * mag2(a, sqrt(a) / q, 1) / mag2(1, sqrt(a) / q, a)
        case .lowPass: return 1 / mag2(1, 1 / q, 1)
        case .highPass: return mag2(1, 0, 0) / mag2(1, 1 / q, 1)
        case .notch: return mag2(1, 0, 1) / mag2(1, 1 / q, 1)
        case .bandPass: return mag2(0, 1 / q, 0) / mag2(1, 1 / q, 1)
        }
    }

    /// Vicanek's matched second-order design: poles by impulse invariance of
    /// the analog prototype, zeros chosen so the digital magnitude equals the
    /// analog one at DC, ω0 and Nyquist. Unlike the bilinear transform this
    /// keeps peaks and shelves near Nyquist at their intended width and
    /// height, so a preset sounds the same at 44.1 and 96 kHz. Returns nil
    /// when the pole frequency is too close to Nyquist for the match to be
    /// meaningful; the caller then falls back to the bilinear design.
    private static func makeMatched(type: FilterType, w0: Double, a: Double, q: Double) -> BiquadCoefficients? {
        // Natural frequency (relative to ω0) and Q of the prototype's denominator.
        let (poleRatio, poleQ): (Double, Double) = switch type {
        case .peak: (1, a * q)
        case .lowShelf: (1 / sqrt(a), q)
        case .highShelf: (sqrt(a), q)
        case .lowPass, .highPass, .notch, .bandPass: (1, q)
        }
        let wp = w0 * poleRatio
        guard wp < 0.95 * Double.pi else { return nil }

        let zeta = 1 / (2 * poleQ)
        let decay = exp(-zeta * wp)
        let a2 = decay * decay
        let a1 = zeta <= 1
            ? -2 * decay * cos(sqrt(1 - zeta * zeta) * wp)
            : -2 * decay * cosh(sqrt(zeta * zeta - 1) * wp)

        // |D(e^jω)|² = A0 φ0 + A1 φ1 + A2 φ2 with φ = sin²(ω/2).
        let A0 = (1 + a1 + a2) * (1 + a1 + a2)
        let A1 = (1 - a1 + a2) * (1 - a1 + a2)
        let A2 = -4 * a2
        let phi = sin(w0 / 2) * sin(w0 / 2)
        let phi0 = 1 - phi, phi1 = phi, phi2 = 4 * phi * (1 - phi)

        let hDC = analogMagnitudeSquared(type: type, ratio: 0, a: a, q: q)
        let hNyquist = analogMagnitudeSquared(type: type, ratio: Double.pi / w0, a: a, q: q)
        let hCenter = analogMagnitudeSquared(type: type, ratio: 1, a: a, q: q)
        let B0 = A0 * hDC
        let B1 = A1 * hNyquist
        let B2 = (hCenter * (A0 * phi0 + A1 * phi1 + A2 * phi2) - B0 * phi0 - B1 * phi1) / phi2

        let sumEven = (sqrt(B0) + sqrt(B1)) / 2  // b0 + b2
        // Rounding can push an exact zero (high-pass, notch) slightly negative.
        let discriminant = sumEven * sumEven + B2
        guard discriminant >= -1e-9 else { return nil }
        let b0 = (sumEven + sqrt(max(discriminant, 0))) / 2
        let b2 = sumEven - b0
        let b1 = (sqrt(B0) - sqrt(B1)) / 2
        guard [b0, b1, b2, a1, a2].allSatisfy(\.isFinite) else { return nil }
        return BiquadCoefficients(b0: Float(b0), b1: Float(b1), b2: Float(b2), a1: Float(a1), a2: Float(a2))
    }

    // MARK: Bilinear (RBJ cookbook) design

    static func makeBilinear(type: FilterType, w0: Double, a: Double, q: Double) -> BiquadCoefficients {
        let cosw = cos(w0), sinw = sin(w0)
        let alpha = sinw / (2.0 * q)

        var b0 = 1.0, b1 = 0.0, b2 = 0.0, a0 = 1.0, a1 = 0.0, a2 = 0.0
        switch type {
        case .peak:
            b0 = 1 + alpha * a
            b1 = -2 * cosw
            b2 = 1 - alpha * a
            a0 = 1 + alpha / a
            a1 = -2 * cosw
            a2 = 1 - alpha / a
        case .lowShelf:
            let s = 2 * sqrt(a) * alpha
            b0 = a * ((a + 1) - (a - 1) * cosw + s)
            b1 = 2 * a * ((a - 1) - (a + 1) * cosw)
            b2 = a * ((a + 1) - (a - 1) * cosw - s)
            a0 = (a + 1) + (a - 1) * cosw + s
            a1 = -2 * ((a - 1) + (a + 1) * cosw)
            a2 = (a + 1) + (a - 1) * cosw - s
        case .highShelf:
            let s = 2 * sqrt(a) * alpha
            b0 = a * ((a + 1) + (a - 1) * cosw + s)
            b1 = -2 * a * ((a - 1) + (a + 1) * cosw)
            b2 = a * ((a + 1) + (a - 1) * cosw - s)
            a0 = (a + 1) - (a - 1) * cosw + s
            a1 = 2 * ((a - 1) - (a + 1) * cosw)
            a2 = (a + 1) - (a - 1) * cosw - s
        case .lowPass:
            b0 = (1 - cosw) / 2
            b1 = 1 - cosw
            b2 = (1 - cosw) / 2
            a0 = 1 + alpha
            a1 = -2 * cosw
            a2 = 1 - alpha
        case .highPass:
            b0 = (1 + cosw) / 2
            b1 = -(1 + cosw)
            b2 = (1 + cosw) / 2
            a0 = 1 + alpha
            a1 = -2 * cosw
            a2 = 1 - alpha
        case .notch:
            b0 = 1
            b1 = -2 * cosw
            b2 = 1
            a0 = 1 + alpha
            a1 = -2 * cosw
            a2 = 1 - alpha
        case .bandPass:
            b0 = alpha
            b1 = 0
            b2 = -alpha
            a0 = 1 + alpha
            a1 = -2 * cosw
            a2 = 1 - alpha
        }
        return BiquadCoefficients(b0: Float(b0 / a0), b1: Float(b1 / a0), b2: Float(b2 / a0),
                                  a1: Float(a1 / a0), a2: Float(a2 / a0))
    }

    /// Magnitude response in dB at `frequency` for a given sample rate.
    func magnitudeDB(at frequency: Double, sampleRate: Double) -> Double {
        let b0 = Double(b0), b1 = Double(b1), b2 = Double(b2)
        let a1 = Double(a1), a2 = Double(a2)
        let w = 2.0 * Double.pi * frequency / sampleRate
        // |H(e^jw)|^2 = (b0^2 + b1^2 + b2^2 + 2(b0b1 + b1b2)cos w + 2 b0b2 cos 2w) /
        //               (1 + a1^2 + a2^2 + 2(a1 + a1a2)cos w + 2 a2 cos 2w)
        let cw = cos(w), c2w = cos(2 * w)
        let num = b0 * b0 + b1 * b1 + b2 * b2 + 2 * (b0 * b1 + b1 * b2) * cw + 2 * b0 * b2 * c2w
        let den = 1 + a1 * a1 + a2 * a2 + 2 * (a1 + a1 * a2) * cw + 2 * a2 * c2w
        guard den > 0, num > 0 else { return -120 }
        return 10 * log10(num / den)
    }
}

/// Per-channel biquad state, transposed direct form II.
struct BiquadState {
    var z1: Float = 0, z2: Float = 0

    @inline(__always)
    mutating func process(_ x: Float, _ c: BiquadCoefficients) -> Float {
        let y = c.b0 * x + z1
        z1 = c.b1 * x - c.a1 * y + z2
        z2 = c.b2 * x - c.a2 * y
        return y
    }
}

enum EQResponse {
    /// Combined magnitude response (dB) of enabled bands + preamp over the given frequencies.
    static func curve(bands: [EQBand], preampDB: Double, frequencies: [Double], sampleRate: Double = 48000) -> [Double] {
        let coeffs = bands.filter(\.isEnabled).map {
            BiquadCoefficients.make(type: $0.type, frequency: $0.frequency, gainDB: $0.gain, q: $0.q, sampleRate: sampleRate)
        }
        return frequencies.map { f in
            coeffs.reduce(preampDB) { $0 + $1.magnitudeDB(at: f, sampleRate: sampleRate) }
        }
    }

    /// Standard log-spaced frequency grid, 20 Hz – 20 kHz.
    static func logGrid(count: Int = 256) -> [Double] {
        let lo = log10(20.0), hi = log10(20000.0)
        return (0..<count).map { pow(10, lo + (hi - lo) * Double($0) / Double(count - 1)) }
    }

    /// Preamp (≤ 0) that keeps the combined response from exceeding 0 dB.
    static func autoPreamp(bands: [EQBand], sampleRate: Double = 48000) -> Double {
        let peak = curve(bands: bands, preampDB: 0, frequencies: logGrid(count: 512), sampleRate: sampleRate).max() ?? 0
        return peak > 0 ? -(peak * 100).rounded(.up) / 100 : 0
    }
}
