import Combine
import Foundation

@MainActor
final class AppNavigationModel: ObservableObject {
    enum MainContent: Int {
        case pipeline
        case settings
    }

    @Published var mainContent: MainContent = .pipeline

    func showSettings() {
        mainContent = .settings
    }

    func showPipeline() {
        mainContent = .pipeline
    }
}
