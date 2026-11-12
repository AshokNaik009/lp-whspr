import Foundation

/// Prepares 16 kHz mono samples for Whisper: trims leading/trailing silence and lifts quiet recordings.
public enum AudioPreprocessor {
    /// Frame RMS below this counts as silence.
    static let silenceRMS: Float = 0.006
    /// Peak level quiet recordings are boosted towards.
    static let targetPeak: Float = 0.9
    static let maxGain: Float = 8

    public static func prepare(_ samples: [Float], sampleRate: Double = 16_000) -> [Float] {
        normalized(trimmed(samples, sampleRate: sampleRate))
    }

    /// Drops silence at both ends, keeping a short margin so word onsets aren't clipped.
    /// Returns the input unchanged when it is silence throughout.
    public static func trimmed(_ samples: [Float], sampleRate: Double = 16_000) -> [Float] {
        let frame = max(1, Int(sampleRate * 0.02))
        let margin = Int(sampleRate * 0.25)
        let frameCount = samples.count / frame
        guard frameCount > 0 else { return samples }

        func isVoiced(_ index: Int) -> Bool {
            var sum: Float = 0
            for s in samples[(index * frame)..<((index + 1) * frame)] { sum += s * s }
            return (sum / Float(frame)).squareRoot() >= silenceRMS
        }
        guard let first = (0..<frameCount).first(where: isVoiced),
              let last = (0..<frameCount).last(where: isVoiced) else { return samples }
        let start = max(0, first * frame - margin)
        let end = min(samples.count, (last + 1) * frame + margin)
        return Array(samples[start..<end])
    }

    /// Scales so the peak reaches `targetPeak`, never attenuating and never boosting more than `maxGain`.
    public static func normalized(_ samples: [Float]) -> [Float] {
        let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
        guard peak > 0 else { return samples }
        let gain = min(maxGain, targetPeak / peak)
        guard gain > 1.05 else { return samples }
        return samples.map { $0 * gain }
    }
}
