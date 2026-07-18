import SwiftUI

/// Onboarding premier lancement — version minimale (Phase 4 : pager complet).
struct OnboardingView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 16) {
            Text("Bienvenue dans MeetingBrief").font(.title2.weight(.semibold))
            Button("Commencer") {
                UserDefaults.standard.set(true, forKey: Prefs.hasCompletedOnboarding)
                state.step = .input
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
