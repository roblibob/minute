@preconcurrency import AVFoundation
import Foundation
import XCTest

@testable import MinuteCore

final class AudioWavConverterTests: XCTestCase {
    func test_convertToContractWav_producesMono16kInt16Wav() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-audio-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let inputURL = tempDir.appendingPathComponent("input.wav")
        let outputURL = tempDir.appendingPathComponent("output.wav")

        // Generate 1 second of stereo float audio at 48 kHz.
        // Use the file's *actual* processingFormat when building the buffer to avoid container quirks.
        let frameCount = AVAudioFrameCount(48_000)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48_000.0,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        do {
            let inputFile = try AVAudioFile(forWriting: inputURL, settings: settings)
            let inputFormat = inputFile.processingFormat

            guard let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frameCount) else {
                XCTFail("Failed to create buffer")
                return
            }

            buffer.frameLength = frameCount

            let frequency: Double = 440
            let sampleRate = inputFormat.sampleRate

            if inputFormat.isInterleaved {
                // One buffer containing LRLRLR...
                let audioBufferList = buffer.audioBufferList.pointee
                guard audioBufferList.mNumberBuffers == 1 else {
                    XCTFail("Expected 1 interleaved buffer")
                    return
                }

                guard let mData = audioBufferList.mBuffers.mData else {
                    XCTFail("Missing interleaved buffer data")
                    return
                }

                let sampleCount = Int(frameCount) * Int(inputFormat.channelCount)
                let ptr = mData.bindMemory(to: Float.self, capacity: sampleCount)

                for frame in 0 ..< Int(frameCount) {
                    let t = Double(frame) / sampleRate
                    let value = Float(sin(2.0 * Double.pi * frequency * t) * 0.25)

                    let base = frame * 2
                    ptr[base] = value
                    ptr[base + 1] = value
                }
            } else {
                // Non-interleaved: one buffer per channel.
                guard let ch0 = buffer.floatChannelData?[0], let ch1 = buffer.floatChannelData?[1] else {
                    XCTFail("Missing float channel data")
                    return
                }

                for frame in 0 ..< Int(frameCount) {
                    let t = Double(frame) / sampleRate
                    let value = Float(sin(2.0 * Double.pi * frequency * t) * 0.25)
                    ch0[frame] = value
                    ch1[frame] = value
                }
            }

            try inputFile.write(from: buffer)
        }

        // Sanity-check: the input file is readable.
        do {
            let readFile = try AVAudioFile(forReading: inputURL)
            guard let sanityBuffer = AVAudioPCMBuffer(pcmFormat: readFile.processingFormat, frameCapacity: 1024) else {
                XCTFail("Failed to create sanity buffer")
                return
            }
            try readFile.read(into: sanityBuffer)
            XCTAssert(sanityBuffer.frameLength > 0, "Expected readable input audio")
        }

        // Convert.
        try await AudioWavConverter.convertToContractWav(inputURL: inputURL, outputURL: outputURL)

        // Verify contract.
        try ContractWavVerifier.verifyContractWav(at: outputURL)

        // Duration should be ~1 second.
        let duration = try ContractWavVerifier.durationSeconds(ofContractWavAt: outputURL)
        XCTAssert(duration > 0.9 && duration < 1.1, "Expected ~1s duration, got \(duration)")
    }
}
