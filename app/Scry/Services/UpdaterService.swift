import Foundation
import Sparkle

final class UpdaterService: ObservableObject {
    static let shared = UpdaterService()

    private let updaterController: SPUStandardUpdaterController

    @Published var canCheckForUpdates = false

    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private init() {
        // Don't start the updater automatically in test environments
        // (SPUStandardUpdaterController with startingUpdater:true can hang in headless CI)
        let hasFeedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let shouldStart = hasFeedURL != nil && !hasFeedURL!.isEmpty

        updaterController = SPUStandardUpdaterController(
            startingUpdater: shouldStart,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
