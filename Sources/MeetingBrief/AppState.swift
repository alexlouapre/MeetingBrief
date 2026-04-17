import Foundation
import SwiftUI

enum Step {
    case input
    case analyzing
    case review
    case sending
    case done
    case settings
}

@MainActor
final class AppState: ObservableObject {
    @Published var step: Step = .input
    @Published var transcript: String = ""
    @Published var analysis: MeetingAnalysis?
    @Published var errorMessage: String?
    @Published var slackChannels: [SlackChannel] = []

    func reset() {
        step = .input
        transcript = ""
        analysis = nil
        errorMessage = nil
    }
}
