import Combine
import Foundation
#if canImport(Sparkle)
import Sparkle
#endif

protocol UpdateDriver: AnyObject {
    var canCheckForUpdates: Bool { get }
    var automaticallyChecksForUpdates: Bool { get set }
    var automaticallyDownloadsUpdates: Bool { get set }

    var canCheckForUpdatesPublisher: AnyPublisher<Bool, Never> { get }
    var automaticallyChecksForUpdatesPublisher: AnyPublisher<Bool, Never> { get }
    var automaticallyDownloadsUpdatesPublisher: AnyPublisher<Bool, Never> { get }

    func checkForUpdates()
}

final class UpdaterViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    @Published var automaticallyChecksForUpdates = true
    @Published var automaticallyDownloadsUpdates = false

    let isUpdaterEnabled: Bool

    private let driver: UpdateDriver
    private var cancellables = Set<AnyCancellable>()

    init(driver: UpdateDriver, isUpdaterEnabled: Bool) {
        self.driver = driver
        self.isUpdaterEnabled = isUpdaterEnabled

        if isUpdaterEnabled {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: "SUAutomaticallyChecksForUpdates") == nil {
                driver.automaticallyChecksForUpdates = true
            }

            canCheckForUpdates = driver.canCheckForUpdates
            automaticallyChecksForUpdates = driver.automaticallyChecksForUpdates
            automaticallyDownloadsUpdates = driver.automaticallyDownloadsUpdates

            driver.canCheckForUpdatesPublisher
                .receive(on: RunLoop.main)
                .sink { [weak self] value in
                    self?.canCheckForUpdates = value
                }
                .store(in: &cancellables)

            driver.automaticallyChecksForUpdatesPublisher
                .receive(on: RunLoop.main)
                .sink { [weak self] value in
                    self?.automaticallyChecksForUpdates = value
                }
                .store(in: &cancellables)

            driver.automaticallyDownloadsUpdatesPublisher
                .receive(on: RunLoop.main)
                .sink { [weak self] value in
                    self?.automaticallyDownloadsUpdates = value
                }
                .store(in: &cancellables)
        } else {
            canCheckForUpdates = false
            automaticallyChecksForUpdates = false
            automaticallyDownloadsUpdates = false
        }
    }

    func checkForUpdates() {
        guard isUpdaterEnabled else { return }
        driver.checkForUpdates()
    }

    func setAutomaticallyChecksForUpdates(_ value: Bool) {
        guard isUpdaterEnabled else { return }
        driver.automaticallyChecksForUpdates = value
        automaticallyChecksForUpdates = driver.automaticallyChecksForUpdates
    }

    func setAutomaticallyDownloadsUpdates(_ value: Bool) {
        guard isUpdaterEnabled else { return }
        driver.automaticallyDownloadsUpdates = value
        automaticallyDownloadsUpdates = driver.automaticallyDownloadsUpdates
    }

    static var preview: UpdaterViewModel {
        UpdaterViewModel(driver: PreviewUpdateDriver(), isUpdaterEnabled: true)
    }
}

final class DisabledUpdateDriver: UpdateDriver {
    private let canCheckSubject = CurrentValueSubject<Bool, Never>(false)
    private let autoCheckSubject = CurrentValueSubject<Bool, Never>(false)
    private let autoDownloadSubject = CurrentValueSubject<Bool, Never>(false)

    var canCheckForUpdates: Bool { canCheckSubject.value }

    var automaticallyChecksForUpdates: Bool {
        get { autoCheckSubject.value }
        set { autoCheckSubject.send(false) }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { autoDownloadSubject.value }
        set { autoDownloadSubject.send(false) }
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

    func checkForUpdates() {}
}

final class PreviewUpdateDriver: UpdateDriver {
    private let canCheckSubject = CurrentValueSubject<Bool, Never>(true)
    private let autoCheckSubject = CurrentValueSubject<Bool, Never>(true)
    private let autoDownloadSubject = CurrentValueSubject<Bool, Never>(false)

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

    func checkForUpdates() {}
}

#if canImport(Sparkle)
final class SparkleUpdateDriver: UpdateDriver {
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
    }

    var canCheckForUpdates: Bool {
        updater.canCheckForUpdates
    }

    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { updater.automaticallyDownloadsUpdates }
        set { updater.automaticallyDownloadsUpdates = newValue }
    }

    var canCheckForUpdatesPublisher: AnyPublisher<Bool, Never> {
        updater.publisher(for: \.canCheckForUpdates).eraseToAnyPublisher()
    }

    var automaticallyChecksForUpdatesPublisher: AnyPublisher<Bool, Never> {
        updater.publisher(for: \.automaticallyChecksForUpdates).eraseToAnyPublisher()
    }

    var automaticallyDownloadsUpdatesPublisher: AnyPublisher<Bool, Never> {
        updater.publisher(for: \.automaticallyDownloadsUpdates).eraseToAnyPublisher()
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}
#endif
