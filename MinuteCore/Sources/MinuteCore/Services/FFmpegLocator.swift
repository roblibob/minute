import Foundation

public enum FFmpegLocator {
    /// Locates the ffmpeg executable, preferring an explicit override.
    ///
    /// Resolution order:
    /// 1) `MINUTE_FFMPEG_BIN` environment variable
    /// 2) `ffmpeg` resource in the main bundle
    /// 3) `ffmpeg` next to the main executable
    public static func locateFFmpegExecutableURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        bundle: Bundle = .main
    ) throws -> URL {
        if let env = environment["MINUTE_FFMPEG_BIN"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }

        if let bundled = bundle.url(forResource: "ffmpeg", withExtension: nil),
           fileManager.isExecutableFile(atPath: bundled.path) {
            return bundled
        }

        if let executableFolder = bundle.executableURL?.deletingLastPathComponent() {
            let bundledExecutable = executableFolder.appendingPathComponent("ffmpeg")
            if fileManager.isExecutableFile(atPath: bundledExecutable.path) {
                return bundledExecutable
            }
        }

        throw MinuteError.ffmpegMissing
    }
}
