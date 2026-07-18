import SwiftUI

// Helpers Liquid Glass (macOS 26). Règle : ne jamais imbriquer un glassEffect
// dans un autre — un GlassEffectContainer par région d'écran.
extension View {
    /// Carte glass standard : padding + effet regular sur rect arrondi, teinte optionnelle.
    func glassCard(cornerRadius: CGFloat = 16, tint: Color? = nil) -> some View {
        let glass: Glass = tint.map { .regular.tint($0) } ?? .regular
        return self
            .padding(14)
            .glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
    }

    /// Bouton icône rond interactif (gear, close…).
    func glassCircleIcon() -> some View {
        self
            .padding(7)
            .glassEffect(.regular.interactive(), in: Circle())
    }
}
