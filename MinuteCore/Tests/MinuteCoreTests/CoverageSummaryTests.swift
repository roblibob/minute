import Foundation
import Testing
@testable import MinuteCore

struct CoverageSummaryTests {
    @Test
    func coverageScript_requiresXCResultPath() throws {
        let scriptURL = repositoryRoot().appendingPathComponent("scripts/coverage/generate-coverage-summary.sh")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]

        try process.run()
        process.waitUntilExit()

        expectEqual(process.terminationStatus, 2)
    }
}

private func repositoryRoot() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 {
        url.deleteLastPathComponent()
    }
    return url
}
