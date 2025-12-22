import AVFoundation
import CoreMedia
import Foundation
@preconcurrency import ScreenCaptureKit
import os

final class SystemAudioCapture: @unchecked Sendable {
    private let stream: SCStream
    private let output: SystemAudioOutput
    private let writer: SampleBufferAudioWriter

    private init(stream: SCStream, output: SystemAudioOutput, writer: SampleBufferAudioWriter) {
        self.stream = stream
        self.output = output
        self.writer = writer
    }

    static func start(
        outputURL: URL,
        logger: Logger,
        levelHandler: (@Sendable (Float) -> Void)?
    ) async throws -> SystemAudioCapture {
        let content = try await fetchShareableContent()
        guard let display = content.displays.first else {
            throw MinuteError.audioExportFailed
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.sampleRate = 48_000
        configuration.channelCount = 1
        configuration.excludesCurrentProcessAudio = true

        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        let writer = SampleBufferAudioWriter(outputURL: outputURL, logger: logger, levelHandler: levelHandler)
        let output = SystemAudioOutput(writer: writer)

        try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: output.queue)
        try await startCapture(stream)

        return SystemAudioCapture(stream: stream, output: output, writer: writer)
    }

    func stop() async throws {
        try await SystemAudioCapture.stopCapture(stream)
        if writer.takeError() != nil {
            throw MinuteError.audioExportFailed
        }
    }
}

private extension SystemAudioCapture {
    static func fetchShareableContent() async throws -> SCShareableContent {
        try await withCheckedThrowingContinuation { continuation in
            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let content {
                    continuation.resume(returning: content)
                } else {
                    continuation.resume(throwing: MinuteError.audioExportFailed)
                }
            }
        }
    }

    static func startCapture(_ stream: SCStream) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stream.startCapture { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    static func stopCapture(_ stream: SCStream) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stream.stopCapture { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

private final class SystemAudioOutput: NSObject, SCStreamOutput {
    let queue = DispatchQueue(label: "roblibob.Minute.systemAudioOutput")
    private let writer: SampleBufferAudioWriter

    init(writer: SampleBufferAudioWriter) {
        self.writer = writer
        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        writer.write(sampleBuffer)
    }
}

private final class SampleBufferAudioWriter {
    private let outputURL: URL
    private let logger: Logger
    private let levelHandler: (@Sendable (Float) -> Void)?
    private let lock = NSLock()
    private var audioFile: AVAudioFile?
    private var writeError: Error?

    init(outputURL: URL, logger: Logger, levelHandler: (@Sendable (Float) -> Void)?) {
        self.outputURL = outputURL
        self.logger = logger
        self.levelHandler = levelHandler
    }

    func write(_ sampleBuffer: CMSampleBuffer) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frameCount > 0 else { return }

        do {
            let pcmBuffer = try Self.makePCMBuffer(from: sampleBuffer)
            let file = try audioFile ?? AVAudioFile(forWriting: outputURL, settings: pcmBuffer.format.settings)
            audioFile = file
            try file.write(from: pcmBuffer)
            levelHandler?(Self.level(for: pcmBuffer))
        } catch {
            record(error)
        }
    }

    func takeError() -> Error? {
        lock.lock()
        defer { lock.unlock() }
        return writeError
    }

    private func record(_ error: Error) {
        lock.lock()
        let shouldLog = (writeError == nil)
        if shouldLog {
            writeError = error
        }
        lock.unlock()
        if shouldLog {
            logger.error("System audio write failed: \(String(describing: error), privacy: .public)")
        }
    }

    private static func makePCMBuffer(from sampleBuffer: CMSampleBuffer) throws -> AVAudioPCMBuffer {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription),
              let format = AVAudioFormat(streamDescription: asbdPointer) else {
            throw MinuteError.audioExportFailed
        }

        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw MinuteError.audioExportFailed
        }
        pcmBuffer.frameLength = frameCount

        let maxBuffers = Int(asbdPointer.pointee.mChannelsPerFrame)
        let bufferList = AudioBufferList.allocate(maximumBuffers: maxBuffers)
        defer {
            bufferList.unsafeMutablePointer.deinitialize(count: 1)
            bufferList.unsafeMutablePointer.deallocate()
        }

        var blockBuffer: CMBlockBuffer?
        let bufferListSize = AudioBufferList.sizeInBytes(maximumBuffers: maxBuffers)
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: bufferList.unsafeMutablePointer,
            bufferListSize: bufferListSize,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else {
            throw MinuteError.audioExportFailed
        }

        let destination = UnsafeMutableAudioBufferListPointer(pcmBuffer.mutableAudioBufferList)
        for index in 0..<min(bufferList.count, destination.count) {
            let sourceBuffer = bufferList[index]
            guard let sourceData = sourceBuffer.mData else { continue }
            let destinationBuffer = destination[index]
            guard let destinationData = destinationBuffer.mData else { continue }
            memcpy(destinationData, sourceData, Int(sourceBuffer.mDataByteSize))
            destination[index].mDataByteSize = sourceBuffer.mDataByteSize
        }

        return pcmBuffer
    }

    private static func level(for buffer: AVAudioPCMBuffer) -> Float {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        if let channelData = buffer.floatChannelData {
            let channel = channelData[0]
            var sum: Float = 0
            for index in 0..<frameLength {
                let sample = channel[index]
                sum += sample * sample
            }

            let rms = sqrt(sum / Float(frameLength))
            return min(max(rms * 4, 0), 1)
        }

        if let channelData = buffer.int16ChannelData {
            let channel = channelData[0]
            let scale = 1.0 / Float(Int16.max)
            var sum: Float = 0
            for index in 0..<frameLength {
                let sample = Float(channel[index]) * scale
                sum += sample * sample
            }

            let rms = sqrt(sum / Float(frameLength))
            return min(max(rms * 4, 0), 1)
        }

        return 0
    }
}
