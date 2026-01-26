@preconcurrency import AVFoundation
import Foundation
import XCTest

@testable import MinuteCore

final class RecordingRecoveryServiceTests: XCTestCase {
    func test_findRecoverableRecordings_usesMarkerStartDate() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
        let sessionURL = tempRoot.appendingPathComponent("minute-capture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sessionURL) }

        let captureURL = sessionURL.appendingPathComponent("capture.caf")
        try Data().write(to: captureURL, options: [.atomic])

        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let marker = RecordingSessionMarker(
            startedAt: startedAt,
            microphoneEnabled: true,
            systemAudioEnabled: false
        )
        try RecordingSessionMarkerStore.write(marker, to: sessionURL)

        let service = DefaultRecordingRecoveryService()
        let recordings = await service.findRecoverableRecordings()

        guard let found = recordings.first(where: { $0.sessionURL == sessionURL }) else {
            XCTFail("Expected to find recovery session")
            return
        }

        XCTAssertEqual(found.startedAt.timeIntervalSince1970, startedAt.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(found.captureURL, captureURL)
        XCTAssertEqual(found.microphoneEnabled, true)
        XCTAssertEqual(found.systemAudioEnabled, false)
    }

    func test_recover_createsContractWavFromCapture() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
        let sessionURL = tempRoot.appendingPathComponent("minute-capture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sessionURL) }

        let captureURL = sessionURL.appendingPathComponent("capture.caf")
        try writeTestCapture(to: captureURL, durationSeconds: 1.0)

        let startedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let marker = RecordingSessionMarker(
            startedAt: startedAt,
            microphoneEnabled: true,
            systemAudioEnabled: false
        )
        try RecordingSessionMarkerStore.write(marker, to: sessionURL)

        let service = DefaultRecordingRecoveryService()
        let recording = RecoverableRecording(
            id: sessionURL.lastPathComponent,
            sessionURL: sessionURL,
            startedAt: startedAt,
            captureURL: captureURL,
            systemCaptureURL: nil,
            contractWavURL: nil,
            microphoneEnabled: true,
            systemAudioEnabled: false
        )

        let result = try await service.recover(recording: recording)

        try ContractWavVerifier.verifyContractWav(at: result.wavURL)
        XCTAssert(result.duration > 0.9 && result.duration < 1.1, "Expected ~1s duration, got \(result.duration)")
        XCTAssertEqual(result.startedAt, startedAt)
        XCTAssertEqual(result.stoppedAt, startedAt.addingTimeInterval(result.duration))
    }

    private func writeTestCapture(to url: URL, durationSeconds: Double) throws {
        let sampleRate: Double = 48_000
        let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        let file = try AVAudioFile(forWriting: url, settings: settings)
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw MinuteError.audioExportFailed
        }
        buffer.frameLength = frameCount

        let frequency: Double = 440
        let sampleRateHz = format.sampleRate

        if format.isInterleaved {
            let audioBufferList = buffer.audioBufferList.pointee
            guard audioBufferList.mNumberBuffers == 1,
                  let mData = audioBufferList.mBuffers.mData
            else {
                throw MinuteError.audioExportFailed
            }

            let sampleCount = Int(frameCount) * Int(format.channelCount)
            let ptr = mData.bindMemory(to: Float.self, capacity: sampleCount)

            for frame in 0 ..< Int(frameCount) {
                let t = Double(frame) / sampleRateHz
                let value = Float(sin(2.0 * Double.pi * frequency * t) * 0.25)
                ptr[frame] = value
            }
        } else {
            guard let ch0 = buffer.floatChannelData?[0] else {
                throw MinuteError.audioExportFailed
            }

            for frame in 0 ..< Int(frameCount) {
                let t = Double(frame) / sampleRateHz
                let value = Float(sin(2.0 * Double.pi * frequency * t) * 0.25)
                ch0[frame] = value
            }
        }

        try file.write(from: buffer)
    }
}
