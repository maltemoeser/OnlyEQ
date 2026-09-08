import Foundation

enum FilterType: String, Codable, CaseIterable, Identifiable {
    case peak, lowShelf, highShelf, lowPass, highPass, notch, bandPass

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .peak: "Peak"
        case .lowShelf: "Low Shelf"
        case .highShelf: "High Shelf"
        case .lowPass: "Low Pass"
        case .highPass: "High Pass"
        case .notch: "Notch"
        case .bandPass: "Band Pass"
        }
    }
}

struct EQBand: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var type: FilterType = .peak
    var frequency: Double = 1000
    var gain: Double = 0
    var q: Double = 1.41
    var isEnabled = true
    /// Palette slot, assigned when the band joins a preset and kept for the
    /// band's life, so deleting a neighbour never recolours it. Like `id`,
    /// it is identity rather than value and is ignored by equality.
    var colorIndex: Int?

    private enum CodingKeys: String, CodingKey { case type, frequency, gain, q, isEnabled, colorIndex }

    init(type: FilterType = .peak, frequency: Double = 1000, gain: Double = 0, q: Double = 1.41, isEnabled: Bool = true) {
        self.type = type
        self.frequency = frequency
        self.gain = gain
        self.q = q
        self.isEnabled = isEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decodeIfPresent(FilterType.self, forKey: .type) ?? .peak
        frequency = try c.decode(Double.self, forKey: .frequency)
        gain = try c.decodeIfPresent(Double.self, forKey: .gain) ?? 0
        q = try c.decodeIfPresent(Double.self, forKey: .q) ?? 1.41
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        colorIndex = try c.decodeIfPresent(Int.self, forKey: .colorIndex)
    }

    // `id` is a runtime identity for SwiftUI, not part of the value — it isn't
    // encoded, so equality/hashing must ignore it too.
    static func == (lhs: EQBand, rhs: EQBand) -> Bool {
        lhs.type == rhs.type && lhs.frequency == rhs.frequency && lhs.gain == rhs.gain
            && lhs.q == rhs.q && lhs.isEnabled == rhs.isEnabled
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(frequency)
        hasher.combine(gain)
        hasher.combine(q)
        hasher.combine(isEnabled)
    }

    /// One keyboard step: up/down change gain by 0.5 dB, left/right move
    /// frequency by a semitone. Fine steps are 0.1 dB and a quarter semitone.
    enum NudgeDirection { case up, down, left, right }

    func nudged(_ direction: NudgeDirection, fine: Bool) -> EQBand {
        var band = self
        switch direction {
        case .up, .down:
            let step = fine ? 0.1 : 0.5
            let gain = self.gain + (direction == .up ? step : -step)
            band.gain = min(max((gain * 10).rounded() / 10, -30), 30)
        case .left, .right:
            let semitones = fine ? 0.25 : 1.0
            let factor = pow(2, semitones / 12)
            let frequency = direction == .right ? self.frequency * factor : self.frequency / factor
            band.frequency = min(max(frequency.rounded(), 20), 20000)
        }
        return band
    }

    /// Spoken value for the band's graph handle.
    var accessibilityValue: String {
        let frequency = self.frequency >= 1000
            ? String(format: "%.2f kilohertz", self.frequency / 1000)
            : String(format: "%.0f hertz", self.frequency)
        return String(format: "%@, %.1f dB, Q %.2f%@", frequency, gain, q, isEnabled ? "" : ", disabled")
    }
}

/// A listener's taste laid over a preset's correction bands: a bass shelf,
/// a treble shelf, a tilt about 1 kHz, and how much of the correction to
/// apply. Saved with the preset but kept apart from its bands, so the
/// imported filters stay as they were published.
struct EQAdjustment: Codable, Equatable {
    var bassDB: Double = 0
    var trebleDB: Double = 0
    /// Gain at the treble end; the bass end gets the opposite sign.
    var tiltDB: Double = 0
    /// 0 to 1: the fraction of each band's gain that is applied.
    var strength: Double = 1

    static let neutral = EQAdjustment()
    var isNeutral: Bool { self == .neutral }

    static let bassFrequency = 105.0
    static let trebleFrequency = 2500.0
    static let shelfQ = 0.71
    static let tiltPivot = 1000.0
    static let tiltQ = 0.5

    /// The shelves as filters, appended after the preset's own bands.
    var bands: [EQBand] {
        var result: [EQBand] = []
        if bassDB != 0 {
            result.append(EQBand(type: .lowShelf, frequency: Self.bassFrequency, gain: bassDB, q: Self.shelfQ))
        }
        if trebleDB != 0 {
            result.append(EQBand(type: .highShelf, frequency: Self.trebleFrequency, gain: trebleDB, q: Self.shelfQ))
        }
        if tiltDB != 0 {
            result.append(EQBand(type: .lowShelf, frequency: Self.tiltPivot, gain: -tiltDB, q: Self.tiltQ))
            result.append(EQBand(type: .highShelf, frequency: Self.tiltPivot, gain: tiltDB, q: Self.tiltQ))
        }
        return result
    }
}

struct EQPreset: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var preampDB: Double = 0
    var bands: [EQBand] = [] { didSet { assignBandColors() } }
    var adjustment = EQAdjustment.neutral
    /// Where the preset came from, e.g. "AutoEq parametric", "peqdb", "Imported file".
    var source: String?

    init(id: UUID = UUID(), name: String, preampDB: Double = 0, bands: [EQBand] = [],
         adjustment: EQAdjustment = .neutral, source: String? = nil) {
        self.id = id
        self.name = name
        self.preampDB = preampDB
        self.bands = bands
        self.adjustment = adjustment
        self.source = source
        assignBandColors()
    }

    private enum CodingKeys: String, CodingKey { case id, name, preampDB, bands, adjustment, source }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        preampDB = try c.decodeIfPresent(Double.self, forKey: .preampDB) ?? 0
        bands = try c.decodeIfPresent([EQBand].self, forKey: .bands) ?? []
        adjustment = try c.decodeIfPresent(EQAdjustment.self, forKey: .adjustment) ?? .neutral
        source = try c.decodeIfPresent(String.self, forKey: .source)
        assignBandColors()
    }

    /// What the processor runs and the composite curve shows: the bands with
    /// their gains scaled by strength, then the adjustment's shelves.
    var renderedBands: [EQBand] {
        let scaled = adjustment.strength == 1 ? bands : bands.map { band in
            var band = band
            band.gain *= adjustment.strength
            return band
        }
        return scaled + adjustment.bands
    }

    /// Gives every band without a palette slot the lowest one no other band
    /// holds. Existing slots are never touched.
    private mutating func assignBandColors() {
        var taken = Set(bands.compactMap(\.colorIndex))
        for index in bands.indices where bands[index].colorIndex == nil {
            var slot = 0
            while taken.contains(slot) { slot += 1 }
            bands[index].colorIndex = slot
            taken.insert(slot)
        }
    }

    // Built-ins carry fixed IDs so device profiles that reference them keep
    // resolving across launches (a fresh UUID() per launch would break them).
    static let flat = EQPreset(id: UUID(uuidString: "6F6C7945-5100-4000-8000-000000000001")!, name: "Flat")

    /// A gentle Harman-style bass+treble curve as a friendly built-in.
    static let builtIns: [EQPreset] = [
        .flat,
        EQPreset(id: UUID(uuidString: "6F6C7945-5100-4000-8000-000000000002")!,
                 name: "Harman Target", preampDB: -4, bands: [
            EQBand(type: .lowShelf, frequency: 105, gain: 4.0, q: 0.71),
            EQBand(type: .peak, frequency: 200, gain: -1.0, q: 1.0),
            EQBand(type: .peak, frequency: 3000, gain: 2.0, q: 1.2),
            EQBand(type: .highShelf, frequency: 10000, gain: 1.5, q: 0.71),
        ], source: "Built-in"),
        EQPreset(id: UUID(uuidString: "6F6C7945-5100-4000-8000-000000000003")!,
                 name: "Late Night", preampDB: -2, bands: [
            EQBand(type: .lowShelf, frequency: 120, gain: -4.0, q: 0.71),
            EQBand(type: .peak, frequency: 2500, gain: 2.0, q: 1.0),
            EQBand(type: .highShelf, frequency: 9000, gain: -2.0, q: 0.71),
        ], source: "Built-in"),
    ]

    var isFlat: Bool { renderedBands.allSatisfy { $0.gain == 0 } && preampDB == 0 }

    /// Half-height of the curve display in dB: ±12 by default, widened in 6 dB
    /// steps so an imported band beyond ±12 dB is drawn where it is instead
    /// of pinned to the edge.
    var displayRangeDB: Double {
        let largest = bands.map { abs($0.gain) }.max() ?? 0
        return max(12, (largest / 6).rounded(.up) * 6)
    }
}

/// Preset + volume remembered per output device.
struct DeviceProfile: Codable, Equatable {
    var deviceUID: String
    var deviceName: String
    var presetID: UUID?
    var presetName: String?
    var autoApply = true
}
