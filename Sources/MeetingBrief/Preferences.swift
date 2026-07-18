import Foundation

/// Clés UserDefaults centralisées — mêmes littéraux que les @AppStorage des vues.
enum Prefs {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let validationStepEnabled = "validationStepEnabled"
    static let slackEnabled = "slackEnabled"
    static let obsidianPath = "obsidianPath"
    static let favoriteSlackChannelIds = "favoriteSlackChannelIds"
    static let lastSlackDestinationIds = "lastSlackDestinationIds"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            hasCompletedOnboarding: false,
            validationStepEnabled: false,
            // true par défaut pour ne pas casser les installs existantes qui utilisent Slack
            slackEnabled: true,
        ])
    }
}
