@preconcurrency import AVFoundation
import Foundation
import XCTest

@testable import MinuteCore

final class ContractWavPCMReaderTests: XCTestCase {
    func testReadPCM16Mono_readsSamplesFromContractWav() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-wav-read-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let inputURL = tempDir.appendingPathComponent("input.wav")
        let outputURL = tempDir.appendingPathComponent("output.wav")

        // Generate 0.5 seconds of mono float audio at 48 kHz.
        let frameCount = AVAudioFrameCount(24_000)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48_000.0,
            AVNumberOfChannelsKey: 1,
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
                    ptr[frame] = Float(sin(2.0 * Double.pi * frequency * t) * 0.25)
                }
            } else {
                guard let ch0 = buffer.floatChannelData?[0] else {
                    XCTFail("Missing float channel data")
                    return
                }

                for frame in 0 ..< Int(frameCount) {
                    let t = Double(frame) / sampleRate
                    ch0[frame] = Float(sin(2.0 * Double.pi * frequency * t) * 0.25)
                }
            }

            try inputFile.write(from: buffer)
        }

        // Convert to contract WAV.
        try await AudioWavConverter.convertToContractWav(inputURL: inputURL, outputURL: outputURL)
        try ContractWavVerifier.verifyContractWav(at: outputURL)

        let pcm = try ContractWavPCMReader.readPCM16Mono(at: outputURL)
        XCTAssertEqual(pcm.sampleRate, 16_000)
        XCTAssert(pcm.samples.count > 1_000)

        let floats = pcm.asFloat32()
        XCTAssertEqual(floats.count, pcm.samples.count)
        XCTAssert(floats.allSatisfy { $0 >= -1.0 && $0 <= 1.0 })
        XCTAssert(floats.contains(where: { abs($0) > 0.01 }))
    }
}
