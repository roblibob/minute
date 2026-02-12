import Combine
import Testing
@testable import Minute

@MainActor
struct UpdaterViewModelProfileTests {
    @Test
    func disabledMode_noopsUpdateActions() {
        let driver = FakeUpdateDriver()
        let model = UpdaterViewModel(driver: driver, isUpdaterEnabled: false)

        model.checkForUpdates()
        model.setAutomaticallyChecksForUpdates(true)
        model.setAutomaticallyDownloadsUpdates(true)

        #expect(model.isUpdaterEnabled == false)
        #expect(model.canCheckForUpdates == false)
        #expect(model.automaticallyChecksForUpdates == false)
        #expect(model.automaticallyDownloadsUpdates == false)
        #expect(driver.checkForUpdatesCallCount == 0)
        #expect(driver.automaticallyChecksForUpdates == false)
        #expect(driver.automaticallyDownloadsUpdates == false)
    }

    @Test
    func enabledMode_updatesDriverState() {
        let driver = FakeUpdateDriver(
            canCheckForUpdates: true,
            automaticallyChecksForUpdates: false,
            automaticallyDownloadsUpdates: false
        )
        let model = UpdaterViewModel(driver: driver, isUpdaterEnabled: true)

        model.checkForUpdates()
        model.setAutomaticallyChecksForUpdates(true)
        model.setAutomaticallyDownloadsUpdates(true)

        #expect(model.isUpdaterEnabled == true)
        #expect(driver.checkForUpdatesCallCount == 1)
        #expect(driver.automaticallyChecksForUpdates == true)
        #expect(driver.automaticallyDownloadsUpdates == true)
        #expect(model.automaticallyChecksForUpdates == true)
        #expect(model.automaticallyDownloadsUpdates == true)
    }
}

private final class FakeUpdateDriver: UpdateDriver {
    private let canCheckSubject: CurrentValueSubject<Bool, Never>
    private let autoCheckSubject: CurrentValueSubject<Bool, Never>
    private let autoDownloadSubject: CurrentValueSubject<Bool, Never>

    private(set) var checkForUpdatesCallCount = 0

    init(
        canCheckForUpdates: Bool = false,
        automaticallyChecksForUpdates: Bool = false,
        automaticallyDownloadsUpdates: Bool = false
    ) {
        self.canCheckSubject = CurrentValueSubject(canCheckForUpdates)
        self.autoCheckSubject = CurrentValueSubject(automaticallyChecksForUpdates)
        self.autoDownloadSubject = CurrentValueSubject(automaticallyDownloadsUpdates)
    }

    var canCheckForUpdates: Bool { canCheckSubject.value }

    var automaticallyChecksForUpdates: Bool {
        get { autoCheckSubject.value }
        set { autoCheckSubject.send(newValue) }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { autoDownloadSubject.value }
        set { autoDownloadSubject.send(newValue) }
    }

    var canCheckForUpdatesPublisher: AnyPublisher<Bool, Never> {
        canCheckSubject.eraseToAnyPublisher()
    }

    var automaticallyChecksForUpdatesPublisher: AnyPublisher<Bool, Never> {
        autoCheckSubject.eraseToAnyPublisher()
    }

    var automaticallyDownloadsUpdatesPublisher: AnyPublisher<Bool, Never> {
        autoDownloadSubject.eraseToAnyPublisher()
    }

    func checkForUpdates() {
        checkForUpdatesCallCount += 1
    }
}
