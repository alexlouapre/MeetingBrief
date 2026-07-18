import Foundation

/// Clés UserDefaults centralisées — mêmes littéraux que les @AppStorage des vues.
enum Prefs {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let validationStepEnabled = "validationStepEnabled"
    static let slackEnabled = "slackEnabled"
    static let obsidianPath = "obsidianPath"
    static let favoriteSlackChannelIds = "favoriteSlackChannelIds"
    static let lastSlackDestinationIds = "lastSlackDestinationIds"

    // Modèle & fournisseur LLM. La clé API vit dans SecretStore (pas ici),
    // une par dialecte : "claude_api_key" (anthropic) / "openai_api_key" (openai).
    static let llmProvider = "llmProvider"   // "anthropic" | "openai_compatible"
    static let llmModel = "llmModel"
    static let llmBaseURL = "llmBaseURL"     // dialecte openai only ; vide → https://api.openai.com/v1

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            hasCompletedOnboarding: false,
            validationStepEnabled: false,
            // true par défaut pour ne pas casser les installs existantes qui utilisent Slack
            slackEnabled: true,
            // Defaults = comportement historique (Claude Sonnet via clé existante).
            llmProvider: "anthropic",
            llmModel: "claude-sonnet-5",
            llmBaseURL: "",
        ])
    }
}
