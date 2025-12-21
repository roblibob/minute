import AVFoundation
import AudioToolbox
import Foundation

enum ContractWavVerifier {
    static let requiredSampleRate: Double = 16_000
    static let requiredChannels: AVAudioChannelCount = 1
    static let requiredCommonFormat: AVAudioCommonFormat = .pcmFormatInt16

    static func verifyContractWav(at url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        let format = file.fileFormat

        guard url.pathExtension.lowercased() == "wav" else {
            throw MinuteError.audioExportFailed
        }

        // Sample rate
        guard abs(format.sampleRate - requiredSampleRate) < 0.0001 else {
            throw MinuteError.audioExportFailed
        }

        // Channels
        guard format.channelCount == requiredChannels else {
            throw MinuteError.audioExportFailed
        }

        // PCM 16-bit
        guard format.commonFormat == requiredCommonFormat else {
            throw MinuteError.audioExportFailed
        }

        let stream = format.streamDescription.pointee
        guard stream.mFormatID == kAudioFormatLinearPCM else {
            throw MinuteError.audioExportFailed
        }

        guard stream.mBitsPerChannel == 16 else {
            throw MinuteError.audioExportFailed
        }
    }

    static func durationSeconds(ofContractWavAt url: URL) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: url)
        let format = file.fileFormat
        guard format.sampleRate > 0 else { return 0 }
        return TimeInterval(Double(file.length) / format.sampleRate)
    }
}
