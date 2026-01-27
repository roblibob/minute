@preconcurrency import FluidAudio
import Foundation

enum FluidAudioASRVersionResolver {
    static func version(for key: String) -> AsrModelVersion {
        switch key.lowercased() {
        case "v2":
            return .v2
        default:
            return .v3
        }
    }
}
