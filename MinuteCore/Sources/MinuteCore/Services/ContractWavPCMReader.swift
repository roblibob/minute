import Foundation

/// Minimal WAV reader for our contract audio format.
///
/// Contract requirements:
/// - RIFF/WAVE
/// - PCM (format 1)
/// - Mono
/// - 16 kHz
/// - 16-bit little-endian
public enum ContractWavPCMReader {
    public struct PCM16Mono: Sendable {
        public var sampleRate: Int
        public var samples: [Int16]

        public init(sampleRate: Int, samples: [Int16]) {
            self.sampleRate = sampleRate
            self.samples = samples
        }

        public func asFloat32() -> [Float] {
            // Map Int16 [-32768, 32767] -> Float [-1, 1].
            // Use 32768 to keep -32768 representable.
            samples.map { Float($0) / 32768.0 }
        }
    }

    public static func readPCM16Mono(at wavURL: URL) throws -> PCM16Mono {
        let data = try Data(contentsOf: wavURL)

        func require(_ condition: @autoclosure () -> Bool, _ debug: String) throws {
            guard condition() else {
                throw MinuteError.whisperFailed(exitCode: -1, output: "invalid wav: \(debug)")
            }
        }

        try require(data.count >= 44, "too small")

        // RIFF header
        try require(String(decoding: data[0..<4], as: UTF8.self) == "RIFF", "missing RIFF")
        try require(String(decoding: data[8..<12], as: UTF8.self) == "WAVE", "missing WAVE")

        // Iterate chunks to find fmt and data.
        var offset = 12

        var fmtFound = false
        var audioFormat: UInt16 = 0
        var numChannels: UInt16 = 0
        var sampleRate: UInt32 = 0
        var bitsPerSample: UInt16 = 0

        var dataChunkOffset: Int?
        var dataChunkSize: Int?

        while offset + 8 <= data.count {
            let chunkID = String(decoding: data[offset..<(offset + 4)], as: UTF8.self)
            let chunkSize = Int(readUInt32LE(data, offset + 4))
            let chunkDataStart = offset + 8
            let chunkDataEnd = chunkDataStart + chunkSize

            try require(chunkDataEnd <= data.count, "chunk overruns file")

            if chunkID == "fmt " {
                try require(chunkSize >= 16, "fmt chunk too small")

                audioFormat = readUInt16LE(data, chunkDataStart + 0)
                numChannels = readUInt16LE(data, chunkDataStart + 2)
                sampleRate = readUInt32LE(data, chunkDataStart + 4)
                bitsPerSample = readUInt16LE(data, chunkDataStart + 14)

                fmtFound = true
            } else if chunkID == "data" {
                dataChunkOffset = chunkDataStart
                dataChunkSize = chunkSize
            }

            // Chunks are padded to even sizes.
            offset = chunkDataEnd + (chunkSize % 2)
        }

        try require(fmtFound, "missing fmt chunk")
        try require(audioFormat == 1, "expected PCM format 1")
        try require(numChannels == 1, "expected mono")
        try require(sampleRate == 16_000, "expected 16kHz")
        try require(bitsPerSample == 16, "expected 16-bit")

        guard let dataOffset = dataChunkOffset, let size = dataChunkSize else {
            throw MinuteError.whisperFailed(exitCode: -1, output: "invalid wav: missing data chunk")
        }

        try require(size % 2 == 0, "data chunk not aligned")

        let sampleCount = size / 2
        var samples = [Int16](repeating: 0, count: sampleCount)

        samples.withUnsafeMutableBytes { outBytes in
            let src = data[dataOffset..<(dataOffset + size)]
            outBytes.copyBytes(from: src)
        }

        // WAV is little-endian; Int16 in memory is host-endian.
        if CFByteOrderGetCurrent() == CFByteOrderBigEndian.rawValue {
            for i in samples.indices {
                samples[i] = samples[i].byteSwapped
            }
        }

        return PCM16Mono(sampleRate: Int(sampleRate), samples: samples)
    }

    // MARK: - Little-endian primitives

    private static func readUInt16LE(_ data: Data, _ offset: Int) -> UInt16 {
        let b0 = UInt16(data[offset])
        let b1 = UInt16(data[offset + 1]) << 8
        return b0 | b1
    }

    private static func readUInt32LE(_ data: Data, _ offset: Int) -> UInt32 {
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1]) << 8
        let b2 = UInt32(data[offset + 2]) << 16
        let b3 = UInt32(data[offset + 3]) << 24
        return b0 | b1 | b2 | b3
    }
}
