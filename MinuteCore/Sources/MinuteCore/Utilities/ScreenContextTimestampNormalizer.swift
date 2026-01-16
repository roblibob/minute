import Foundation

enum ScreenContextTimestampNormalizer {
    static func normalize(rawSeconds: Double, firstTimestampSeconds: Double?, offsetSeconds: Double) -> Double {
        let base = firstTimestampSeconds ?? rawSeconds
        let delta = max(0, rawSeconds - base)
        return delta + offsetSeconds
    }
}
