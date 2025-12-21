import Foundation

/// User-configurable vault settings.
///
/// - Note: The vault root itself is persisted via a security-scoped bookmark.
public struct VaultConfiguration: Codable, Equatable, Sendable {
    /// Security-scoped bookmark data for the vault root folder.
    public var vaultRootBookmark: Data

    /// Relative path (from vault root) where meeting notes are stored. Default: `Meetings`.
    public var meetingsRelativePath: String

    /// Relative path (from vault root) where meeting audio is stored. Default: `Meetings/_audio`.
    public var audioRelativePath: String

    /// Relative path (from vault root) where meeting transcripts are stored. Default: `Meetings/_transcripts`.
    public var transcriptsRelativePath: String

    public init(
        vaultRootBookmark: Data,
        meetingsRelativePath: String = "Meetings",
        audioRelativePath: String = "Meetings/_audio",
        transcriptsRelativePath: String = "Meetings/_transcripts"
    ) {
        self.vaultRootBookmark = vaultRootBookmark
        self.meetingsRelativePath = meetingsRelativePath
        self.audioRelativePath = audioRelativePath
        self.transcriptsRelativePath = transcriptsRelativePath
    }
}
