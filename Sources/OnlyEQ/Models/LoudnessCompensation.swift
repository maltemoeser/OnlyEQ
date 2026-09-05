import Foundation

/// Equal-loudness compensation: as the volume drops below the reference
/// level the ear loses bass and treble sensitivity (ISO 226), so a low and a
/// high shelf are raised in proportion to the attenuation. The numbers are a
/// linear fit to the 40–80 phon contours: about 12 dB at 50 Hz and 4 dB at
/// 10 kHz for a 40 dB drop.
enum LoudnessCompensation {
    static let bassShelfHz = 150.0
    static let trebleShelfHz = 6000.0
    static let bassDBPerDB = 0.3
    static let trebleDBPerDB = 0.1
    static let maxBassDB = 12.0
    static let maxTrebleDB = 4.0

    /// Attenuation of `volumePercent` relative to `referencePercent`, in dB (≥ 0).
    static func attenuationDB(volumePercent: Double, referencePercent: Double) -> Double {
        let volume = max(volumePercent, 1)
        let reference = max(referencePercent, 1)
        return max(0, 20 * log10(reference / volume))
    }

    /// Shelves to append to the preset's bands; empty at or above the reference.
    static func bands(volumePercent: Double, referencePercent: Double) -> [EQBand] {
        let attenuation = attenuationDB(volumePercent: volumePercent, referencePercent: referencePercent)
        guard attenuation > 0 else { return [] }
        let bass = min(bassDBPerDB * attenuation, maxBassDB)
        let treble = min(trebleDBPerDB * attenuation, maxTrebleDB)
        return [
            EQBand(type: .lowShelf, frequency: bassShelfHz, gain: (bass * 10).rounded() / 10, q: 0.71),
            EQBand(type: .highShelf, frequency: trebleShelfHz, gain: (treble * 10).rounded() / 10, q: 0.71),
        ]
    }
}
