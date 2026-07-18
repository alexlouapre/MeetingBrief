import SwiftUI

/// Mini picker Slack post-enregistrement — version minimale (Phase 3 : version complète).
struct MiniSlackPickerView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.green)
            Text("Note enregistrée").font(.headline)
            Button("Passer") { state.step = .done }
        }
    }
}
