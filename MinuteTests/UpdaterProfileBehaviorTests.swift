import Foundation
import Testing
@testable import Minute

struct UpdaterProfileBehaviorTests {
    @Test
    func settingsSections_hideUpdatesWhenUpdaterDisabled() {
        let sections = SettingsSection.visibleCases(updatesEnabled: false)

        #expect(sections.contains(.general))
        #expect(sections.contains(.ai))
        #expect(sections.contains(.updates) == false)
    }

    @Test
    func settingsSections_includeUpdatesWhenUpdaterEnabled() {
        let sections = SettingsSection.visibleCases(updatesEnabled: true)

        #expect(sections.contains(.updates))
    }

    @Test
    func distributionConfig_readsProfileAndUpdaterFlagFromInfoPlist() throws {
        let bundleURL = try makeTestBundle(info: [
            "MINUTEDistributionProfile": "app-store",
            "MINUTEEnableUpdater": "NO",
        ])
        defer { try? FileManager.default.removeItem(at: bundleURL.deletingLastPathComponent()) }
        let bundle = try #require(Bundle(url: bundleURL))

        let config = AppDistributionConfiguration.current(bundle: bundle)

        #expect(config.profile == .appStore)
        #expect(config.updaterEnabled == false)
    }
}

private func makeTestBundle(info: [String: Any]) throws -> URL {
    let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("minute-test-bundle-\(UUID().uuidString)", isDirectory: true)
    let bundleURL = tempRoot.appendingPathComponent("Fixture.bundle", isDirectory: true)

    try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

    var plist = info
    plist["CFBundleIdentifier"] = "minute.tests.fixture"
    plist["CFBundleName"] = "Fixture"
    plist["CFBundlePackageType"] = "BNDL"
    plist["CFBundleVersion"] = "1"
    plist["CFBundleShortVersionString"] = "1.0"

    let infoURL = bundleURL.appendingPathComponent("Info.plist")
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try data.write(to: infoURL)

    return bundleURL
}
