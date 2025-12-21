import XCTest
@testable import MinuteCore

final class DefaultModelManagerTests: XCTestCase {
    func testEnsureModelsPresent_downloadsFileURLAndVerifiesSHA() async throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("minute-model-manager-tests-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        // Create a local "source" file.
        let sourceURL = tempDir.appendingPathComponent("source.bin")
        let content = Data("hello".utf8)
        try content.write(to: sourceURL, options: [.atomic])

        // Destination file path (does not exist).
        let destinationURL = tempDir.appendingPathComponent("dest.bin")

        // Compute expected SHA-256 for "hello".
        let expectedSHA = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"

        let manager = DefaultModelManager(
            requiredModels: [
                DefaultModelManager.ModelSpec(
                    id: "test",
                    destinationURL: destinationURL,
                    sourceURL: sourceURL,
                    expectedSHA256Hex: expectedSHA
                ),
            ]
        )

        try await manager.ensureModelsPresent(progress: Optional<(@Sendable (ModelDownloadProgress) -> Void)>.none)

        XCTAssertTrue(fm.fileExists(atPath: destinationURL.path))
        let written = try Data(contentsOf: destinationURL)
        XCTAssertEqual(written, content)
    }

    func testEnsureModelsPresent_whenSHAMismatches_throwsChecksumMismatchAndDoesNotLeaveFile() async throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("minute-model-manager-tests-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let sourceURL = tempDir.appendingPathComponent("source.bin")
        try Data("hello".utf8).write(to: sourceURL, options: [.atomic])

        let destinationURL = tempDir.appendingPathComponent("dest.bin")

        let manager = DefaultModelManager(
            requiredModels: [
                DefaultModelManager.ModelSpec(
                    id: "test",
                    destinationURL: destinationURL,
                    sourceURL: sourceURL,
                    expectedSHA256Hex: "deadbeef"
                ),
            ]
        )

        do {
            try await manager.ensureModelsPresent(progress: Optional<(@Sendable (ModelDownloadProgress) -> Void)>.none)
            XCTFail("Expected to throw")
        } catch let err as MinuteError {
            switch err {
            case .modelChecksumMismatch:
                break
            default:
                XCTFail("Unexpected MinuteError: \(err)")
            }
        }

        XCTAssertFalse(fm.fileExists(atPath: destinationURL.path))
    }
}
