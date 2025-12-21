import AudioToolbox
import Foundation

enum AudioWavConverter {
    /// Converts `inputURL` (any CoreAudio-readable audio) into a deterministic contract WAV.
    ///
    /// Contract:
    /// - mono
    /// - 16 kHz
    /// - 16-bit PCM (signed integer, packed)
    static func convertToContractWav(inputURL: URL, outputURL: URL) async throws {
        try Task.checkCancellation()

        // Ensure we overwrite cleanly.
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        // Desired output format (client format for both read + write).
        var asbd = AudioStreamBasicDescription(
            mSampleRate: ContractWavVerifier.requiredSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: UInt32(ContractWavVerifier.requiredChannels),
            mBitsPerChannel: 16,
            mReserved: 0
        )

        func check(_ status: OSStatus, _ context: StaticString) throws {
            guard status == noErr else {
                // Map all lower-level failures to domain error for now.
                throw MinuteError.audioExportFailed
            }
        }

        var inputFile: ExtAudioFileRef?
        try check(ExtAudioFileOpenURL(inputURL as CFURL, &inputFile), "ExtAudioFileOpenURL")
        guard let inputFile else { throw MinuteError.audioExportFailed }
        defer { ExtAudioFileDispose(inputFile) }

        // Set the client data format, letting ExtAudioFile handle conversion/resampling.
        let asbdSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(ExtAudioFileSetProperty(inputFile, kExtAudioFileProperty_ClientDataFormat, asbdSize, &asbd), "ExtAudioFileSetProperty(input.clientFormat)")

        // Create output WAV file.
        var outputFile: ExtAudioFileRef?
        let flags = AudioFileFlags.eraseFile.rawValue
        try check(
            ExtAudioFileCreateWithURL(outputURL as CFURL, kAudioFileWAVEType, &asbd, nil, flags, &outputFile),
            "ExtAudioFileCreateWithURL"
        )
        guard let outputFile else { throw MinuteError.audioExportFailed }
        defer { ExtAudioFileDispose(outputFile) }

        // Ensure the output also expects client format == file format.
        try check(ExtAudioFileSetProperty(outputFile, kExtAudioFileProperty_ClientDataFormat, asbdSize, &asbd), "ExtAudioFileSetProperty(output.clientFormat)")

        // Allocate an interleaved buffer list.
        let framesPerChunk: UInt32 = 32_768
        let bytesPerFrame = asbd.mBytesPerFrame
        let bufferByteSize = framesPerChunk * bytesPerFrame

        guard let mData = malloc(Int(bufferByteSize)) else {
            throw MinuteError.audioExportFailed
        }
        defer { free(mData) }

        let audioBuffer = AudioBuffer(
            mNumberChannels: asbd.mChannelsPerFrame,
            mDataByteSize: bufferByteSize,
            mData: mData
        )

        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: audioBuffer
        )

        while true {
            try Task.checkCancellation()

            var framesToRead = framesPerChunk

            // Ensure the data byte size is reset each read.
            bufferList.mBuffers.mDataByteSize = bufferByteSize

            try check(ExtAudioFileRead(inputFile, &framesToRead, &bufferList), "ExtAudioFileRead")

            if framesToRead == 0 {
                break
            }

            // Update to the number of bytes actually filled.
            bufferList.mBuffers.mDataByteSize = framesToRead * bytesPerFrame

            try check(ExtAudioFileWrite(outputFile, framesToRead, &bufferList), "ExtAudioFileWrite")
        }
    }
}
