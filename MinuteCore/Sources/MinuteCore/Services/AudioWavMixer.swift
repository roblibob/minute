import AudioToolbox
import Foundation

enum AudioWavMixer {
    /// Mixes `micURL` + `systemURL` into a contract WAV (mono, 16 kHz, 16-bit PCM).
    static func mixToContractWav(micURL: URL, systemURL: URL, outputURL: URL) async throws {
        try Task.checkCancellation()

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        var outputASBD = AudioStreamBasicDescription(
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

        var clientASBD = AudioStreamBasicDescription(
            mSampleRate: ContractWavVerifier.requiredSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: UInt32(ContractWavVerifier.requiredChannels),
            mBitsPerChannel: 32,
            mReserved: 0
        )

        func check(_ status: OSStatus, _ context: StaticString) throws {
            guard status == noErr else {
                throw MinuteError.audioExportFailed
            }
        }

        var micFile: ExtAudioFileRef?
        try check(ExtAudioFileOpenURL(micURL as CFURL, &micFile), "ExtAudioFileOpenURL(mic)")
        guard let micFile else { throw MinuteError.audioExportFailed }
        defer { ExtAudioFileDispose(micFile) }

        var systemFile: ExtAudioFileRef?
        try check(ExtAudioFileOpenURL(systemURL as CFURL, &systemFile), "ExtAudioFileOpenURL(system)")
        guard let systemFile else { throw MinuteError.audioExportFailed }
        defer { ExtAudioFileDispose(systemFile) }

        let asbdSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(ExtAudioFileSetProperty(micFile, kExtAudioFileProperty_ClientDataFormat, asbdSize, &clientASBD), "ExtAudioFileSetProperty(mic.clientFormat)")
        try check(ExtAudioFileSetProperty(systemFile, kExtAudioFileProperty_ClientDataFormat, asbdSize, &clientASBD), "ExtAudioFileSetProperty(system.clientFormat)")

        var outputFile: ExtAudioFileRef?
        let flags = AudioFileFlags.eraseFile.rawValue
        try check(
            ExtAudioFileCreateWithURL(outputURL as CFURL, kAudioFileWAVEType, &outputASBD, nil, flags, &outputFile),
            "ExtAudioFileCreateWithURL"
        )
        guard let outputFile else { throw MinuteError.audioExportFailed }
        defer { ExtAudioFileDispose(outputFile) }

        try check(ExtAudioFileSetProperty(outputFile, kExtAudioFileProperty_ClientDataFormat, asbdSize, &clientASBD), "ExtAudioFileSetProperty(output.clientFormat)")

        let framesPerChunk: UInt32 = 32_768
        let bytesPerFrame = clientASBD.mBytesPerFrame
        let bufferByteSize = framesPerChunk * bytesPerFrame

        guard
            let micData = malloc(Int(bufferByteSize)),
            let systemData = malloc(Int(bufferByteSize)),
            let mixData = malloc(Int(bufferByteSize))
        else {
            throw MinuteError.audioExportFailed
        }
        defer {
            free(micData)
            free(systemData)
            free(mixData)
        }

        let micBuffer = AudioBuffer(
            mNumberChannels: clientASBD.mChannelsPerFrame,
            mDataByteSize: bufferByteSize,
            mData: micData
        )
        let systemBuffer = AudioBuffer(
            mNumberChannels: clientASBD.mChannelsPerFrame,
            mDataByteSize: bufferByteSize,
            mData: systemData
        )
        let mixBuffer = AudioBuffer(
            mNumberChannels: clientASBD.mChannelsPerFrame,
            mDataByteSize: bufferByteSize,
            mData: mixData
        )

        var micBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: micBuffer)
        var systemBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: systemBuffer)
        var mixBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: mixBuffer)

        let micSamples = micData.assumingMemoryBound(to: Float.self)
        let systemSamples = systemData.assumingMemoryBound(to: Float.self)
        let mixSamples = mixData.assumingMemoryBound(to: Float.self)

        while true {
            try Task.checkCancellation()

            var micFrames = framesPerChunk
            micBufferList.mBuffers.mDataByteSize = bufferByteSize
            try check(ExtAudioFileRead(micFile, &micFrames, &micBufferList), "ExtAudioFileRead(mic)")

            var systemFrames = framesPerChunk
            systemBufferList.mBuffers.mDataByteSize = bufferByteSize
            try check(ExtAudioFileRead(systemFile, &systemFrames, &systemBufferList), "ExtAudioFileRead(system)")

            let framesToWrite = max(micFrames, systemFrames)
            if framesToWrite == 0 {
                break
            }

            let micFrameCount = Int(micFrames)
            let systemFrameCount = Int(systemFrames)
            let outputFrameCount = Int(framesToWrite)

            for index in 0..<outputFrameCount {
                var mixed: Float = 0
                if index < micFrameCount {
                    mixed += micSamples[index]
                }
                if index < systemFrameCount {
                    mixed += systemSamples[index]
                }
                if mixed > 1 { mixed = 1 }
                if mixed < -1 { mixed = -1 }
                mixSamples[index] = mixed
            }

            mixBufferList.mBuffers.mDataByteSize = framesToWrite * bytesPerFrame
            try check(ExtAudioFileWrite(outputFile, framesToWrite, &mixBufferList), "ExtAudioFileWrite(mix)")
        }
    }
}
