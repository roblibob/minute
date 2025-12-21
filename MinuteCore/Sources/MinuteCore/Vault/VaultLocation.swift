import Foundation

public struct VaultLocation: Sendable {
    public var vaultRootURL: URL
    public var meetingsRelativePath: String
    public var audioRelativePath: String
    public var transcriptsRelativePath: String

    public init(
        vaultRootURL: URL,
        meetingsRelativePath: String,
        audioRelativePath: String,
        transcriptsRelativePath: String
    ) {
        self.vaultRootURL = vaultRootURL
        self.meetingsRelativePath = meetingsRelativePath
        self.audioRelativePath = audioRelativePath
        self.transcriptsRelativePath = transcriptsRelativePath
    }

    public var meetingsFolderURL: URL {
        vaultRootURL.appendingPathComponents(normalizedRelative(meetingsRelativePath), isDirectory: true)
    }

    public var audioFolderURL: URL {
        vaultRootURL.appendingPathComponents(normalizedRelative(audioRelativePath), isDirectory: true)
    }

    public var transcriptsFolderURL: URL {
        vaultRootURL.appendingPathComponents(normalizedRelative(transcriptsRelativePath), isDirectory: true)
    }

    private func normalizedRelative(_ path: String) -> [String] {
        path
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
    }
}

private extension URL {
    func appendingPathComponents(_ components: [String], isDirectory: Bool) -> URL {
        components.reduce(self) { partial, component in
            partial.appendingPathComponent(component, isDirectory: isDirectory)
        }
    }
}
