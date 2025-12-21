import Foundation
import XCTest
@testable import MinuteCore

final class WhisperTranscriptionServiceTests: XCTestCase {
    private struct MockProcessRunner: ProcessRunning {
        var handler: @Sendable (URL, [String]) async throws -> ProcessResult

        func run(
            executableURL: URL,
            arguments: [String],
            environment: [String: String]?,
            workingDirectoryURL: URL?,
            maximumOutputBytes: Int
        ) async throws -> ProcessResult {
            try await handler(executableURL, arguments)
        }
    }

    func testTranscribe_whenExitCodeZero_returnsNormalizedTranscript() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let exe = tmp.appendingPathComponent("whisper")
        FileManager.default.createFile(atPath: exe.path, contents: Data())
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: exe.path)

        let model = tmp.appendingPathComponent("base.en.bin")
        FileManager.default.createFile(atPath: model.path, contents: Data([0x00]))

        let wav = tmp.appendingPathComponent("in.wav")
        FileManager.default.createFile(atPath: wav.path, contents: Data([0x00]))

        let runner = MockProcessRunner { _, _ in
            ProcessResult(
                exitCode: 0,
                stdout: "[ 12%]\nHello world.\n\n\nThis is a test.\n",
                stderr: ""
            )
        }

        let service = WhisperTranscriptionService(
            configuration: WhisperTranscriptionConfiguration(executableURL: exe, modelURL: model),
            processRunner: runner
        )

        let result = try await service.transcribe(wavURL: wav)
        XCTAssertEqual(result.text, "Hello world.\n\nThis is a test.")
    }

    func testTranscribe_whenNonZeroExitCode_throwsWhisperFailedIncludingOutput() async {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let exe = tmp.appendingPathComponent("whisper")
        FileManager.default.createFile(atPath: exe.path, contents: Data())
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: exe.path)

        let model = tmp.appendingPathComponent("base.en.bin")
        FileManager.default.createFile(atPath: model.path, contents: Data([0x00]))

        let wav = tmp.appendingPathComponent("in.wav")
        FileManager.default.createFile(atPath: wav.path, contents: Data([0x00]))

        let runner = MockProcessRunner { _, _ in
            ProcessResult(exitCode: 2, stdout: "", stderr: "boom")
        }

        let service = WhisperTranscriptionService(
            configuration: WhisperTranscriptionConfiguration(executableURL: exe, modelURL: model),
            processRunner: runner
        )

        do {
            _ = try await service.transcribe(wavURL: wav)
            XCTFail("Expected error")
        } catch let error as MinuteError {
            switch error {
            case .whisperFailed(let exitCode, let output):
                XCTAssertEqual(exitCode, 2)
                XCTAssertTrue(output.contains("boom"))
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranscribe_whenExecutableMissing_throwsWhisperMissing() async {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let exe = tmp.appendingPathComponent("whisper")
        // Note: do not create the file.

        let model = tmp.appendingPathComponent("base.en.bin")
        FileManager.default.createFile(atPath: model.path, contents: Data([0x00]))

        let wav = tmp.appendingPathComponent("in.wav")
        FileManager.default.createFile(atPath: wav.path, contents: Data([0x00]))

        let runner = MockProcessRunner { _, _ in
            XCTFail("Runner should not be invoked")
            return ProcessResult(exitCode: 0, stdout: "", stderr: "")
        }

        let service = WhisperTranscriptionService(
            configuration: WhisperTranscriptionConfiguration(executableURL: exe, modelURL: model),
            processRunner: runner
        )

        do {
            _ = try await service.transcribe(wavURL: wav)
            XCTFail("Expected error")
        } catch let error as MinuteError {
            guard case .whisperMissing = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranscribe_whenModelMissing_throwsModelMissing() async {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let exe = tmp.appendingPathComponent("whisper")
        FileManager.default.createFile(atPath: exe.path, contents: Data())
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: exe.path)

        let model = tmp.appendingPathComponent("base.en.bin")
        // Note: do not create the file.

        let wav = tmp.appendingPathComponent("in.wav")
        FileManager.default.createFile(atPath: wav.path, contents: Data([0x00]))

        let runner = MockProcessRunner { _, _ in
            XCTFail("Runner should not be invoked")
            return ProcessResult(exitCode: 0, stdout: "", stderr: "")
        }

        let service = WhisperTranscriptionService(
            configuration: WhisperTranscriptionConfiguration(executableURL: exe, modelURL: model),
            processRunner: runner
        )

        do {
            _ = try await service.transcribe(wavURL: wav)
            XCTFail("Expected error")
        } catch let error as MinuteError {
            guard case .modelMissing = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
