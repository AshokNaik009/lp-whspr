import Foundation

/// Decides when an on-device result should be re-transcribed in the cloud (spec 003, FR-003-2).
enum FallbackPolicy {
    static let noSpeechCutoff: Float = 0.8

    static func shouldUseCloud(confidence: Float, noSpeechProbability: Float, threshold: Double, cloudAvailable: Bool) -> Bool {
        cloudAvailable && Double(confidence) < threshold && noSpeechProbability < noSpeechCutoff
    }

    /// Suggested threshold from calibration (spec 006, FR-006-6): lowest confidence among accurate results minus 10 points.
    static func suggestedThreshold(results: [(accuracy: Double, confidence: Float)]) -> Double? {
        guard let floor = results.filter({ $0.accuracy >= 0.9 }).map(\.confidence).min() else { return nil }
        return min(0.9, max(0.3, Double(floor) - 0.1))
    }
}
