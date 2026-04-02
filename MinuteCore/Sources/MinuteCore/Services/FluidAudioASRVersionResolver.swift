@preconcurrency import FluidAudio
import Foundation

enum FluidAudioASRVersionResolver {
    static func version(for key: String) -> AsrModelVersion {
        switch key.lowercased() {
        case "v2":
            return .v2
        case "tdtctc110m", "tdt-ctc-110m", "tdt_ctc_110m":
            return .tdtCtc110m
        default:
            return .v3
        }
    }
}
