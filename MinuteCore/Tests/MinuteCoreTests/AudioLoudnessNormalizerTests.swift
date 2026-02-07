import Foundation
import Testing
@testable import MinuteCore

struct AudioLoudnessNormalizerTests {
    @Test
    func pass1Arguments_areDeterministic() throws {
        let inputURL = try makeTemporaryFile(named: "input.wav")
        defer { try? FileManager.default.removeItem(at: inputURL.deletingLastPathComponent()) }

        let a = AudioLoudnessNormalizer.pass1Arguments(inputURL: inputURL)
        let b = AudioLoudnessNormalizer.pass1Arguments(inputURL: inputURL)
        expectEqual(a, b)
    }

    @Test
    func pass2Arguments_areDeterministic() throws {
        let inputURL = try makeTemporaryFile(named: "input.wav")
        let outputURL = inputURL.deletingLastPathComponent().appendingPathComponent("out.wav")
        defer { try? FileManager.default.removeItem(at: inputURL.deletingLastPathComponent()) }

        let measurements = AudioLoudnessNormalizer.LoudnormMeasurements(
            measuredI: "-20.0",
            measuredTP: "-2.0",
            measuredLRA: "5.0",
            measuredThresh: "-30.0",
            offset: "0.0"
        )

        let a = AudioLoudnessNormalizer.pass2Arguments(inputURL: inputURL, outputURL: outputURL, measurements: measurements)
        let b = AudioLoudnessNormalizer.pass2Arguments(inputURL: inputURL, outputURL: outputURL, measurements: measurements)
        expectEqual(a, b)
    }

    @Test
    func normalizeForAnalysis_invokesTwoPassesWithDeterministicArgs_andProducesContractWav() async throws {
        let inputURL = try makeTemporaryFile(named: "input.wav")
        defer { try? FileManager.default.removeItem(at: inputURL.deletingLastPathComponent()) }

        let workingDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-loudnorm-test-\(UUID().uuidString)", isDirectory: true)

        let measurements = AudioLoudnessNormalizer.LoudnormMeasurements(
            measuredI: "-20.0",
            measuredTP: "-2.0",
            measuredLRA: "5.0",
            measuredThresh: "-30.0",
            offset: "0.0"
        )

        let stderr = """
        ffmpeg version N-00000
        [Parsed_loudnorm_0 @ 0x000000000] something
        {\"measured_I\":\"\(measurements.measuredI)\",\"measured_TP\":\"\(measurements.measuredTP)\",\"measured_LRA\":\"\(measurements.measuredLRA)\",\"measured_thresh\":\"\(measurements.measuredThresh)\",\"offset\":\"\(measurements.offset)\"}
        more output
        """

        let runner = StubProcessRunner(pass1Stderr: stderr)
        let normalizer = AudioLoudnessNormalizer(
            processRunner: runner,
            environment: ["MINUTE_FFMPEG_BIN": "/usr/bin/true"]
        )

        let outputURL = try await normalizer.normalizeForAnalysis(inputURL: inputURL, workingDirectoryURL: workingDirectoryURL)

        #expect(outputURL.lastPathComponent == "analysis-normalized.wav")
        #expect(FileManager.default.fileExists(atPath: outputURL.path))

        let calls = await runner.getCalls()
        #expect(calls.count == 2)

        let expectedPass1 = AudioLoudnessNormalizer.pass1Arguments(inputURL: inputURL)
        expectEqual(calls[0].arguments, expectedPass1)

        let expectedPass2 = AudioLoudnessNormalizer.pass2Arguments(
            inputURL: inputURL,
            outputURL: outputURL,
            measurements: measurements
        )
        expectEqual(calls[1].arguments, expectedPass2)
    }
}

private struct StubCall: Sendable, Equatable {
    var executableURL: URL
    var arguments: [String]
    var maximumOutputBytes: Int
}

private actor StubProcessRunner: ProcessRunning {
    private let pass1Stderr: String
    private var calls: [StubCall] = []

    init(pass1Stderr: String) {
        self.pass1Stderr = pass1Stderr
    }

    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        workingDirectoryURL: URL?,
        maximumOutputBytes: Int
    ) async throws -> ProcessResult {
        _ = environment
        _ = workingDirectoryURL

        calls.append(StubCall(executableURL: executableURL, arguments: arguments, maximumOutputBytes: maximumOutputBytes))

        if arguments.contains(where: { $0.contains("print_format=json") }) {
            return ProcessResult(exitCode: 0, stdout: "", stderr: pass1Stderr)
        }

        if let outputPath = arguments.last {
            try createContractWav(at: URL(fileURLWithPath: outputPath))
        }

        return ProcessResult(exitCode: 0, stdout: "", stderr: "")
    }

    func getCalls() -> [StubCall] {
        calls
    }
}

private func createContractWav(at url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

    // Minimal RIFF/WAVE PCM16 mono @ 16kHz file with a single silent sample.
    let numChannels: UInt16 = 1
    let sampleRate: UInt32 = 16_000
    let bitsPerSample: UInt16 = 16
    let bytesPerSample: UInt16 = bitsPerSample / 8
    let byteRate: UInt32 = sampleRate * UInt32(numChannels) * UInt32(bytesPerSample)
    let blockAlign: UInt16 = numChannels * bytesPerSample

    let dataChunkSize: UInt32 = 2 // one sample
    let riffChunkSize: UInt32 = 4 + (8 + 16) + (8 + dataChunkSize)

    var data = Data()
    data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // RIFF
    data.append(contentsOf: littleEndianBytes(riffChunkSize))
    data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // WAVE

    data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // fmt 
    data.append(contentsOf: littleEndianBytes(UInt32(16))) // PCM fmt chunk size
    data.append(contentsOf: littleEndianBytes(UInt16(1))) // audio format PCM
    data.append(contentsOf: littleEndianBytes(numChannels))
    data.append(contentsOf: littleEndianBytes(sampleRate))
    data.append(contentsOf: littleEndianBytes(byteRate))
    data.append(contentsOf: littleEndianBytes(blockAlign))
    data.append(contentsOf: littleEndianBytes(bitsPerSample))

    data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // data
    data.append(contentsOf: littleEndianBytes(dataChunkSize))
    data.append(contentsOf: [0x00, 0x00]) // silent sample

    try data.write(to: url, options: [.atomic])
}

private func littleEndianBytes(_ value: UInt16) -> [UInt8] {
    let v = value.littleEndian
    return [UInt8(truncatingIfNeeded: v & 0xFF), UInt8(truncatingIfNeeded: v >> 8)]
}

private func littleEndianBytes(_ value: UInt32) -> [UInt8] {
    let v = value.littleEndian
    return [
        UInt8(truncatingIfNeeded: v & 0xFF),
        UInt8(truncatingIfNeeded: (v >> 8) & 0xFF),
        UInt8(truncatingIfNeeded: (v >> 16) & 0xFF),
        UInt8(truncatingIfNeeded: (v >> 24) & 0xFF),
    ]
}

private func makeTemporaryFile(named name: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-loudnorm-fixture-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let url = directory.appendingPathComponent(name)
    try Data().write(to: url, options: [.atomic])
    return url
}
