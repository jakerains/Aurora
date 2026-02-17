import SwiftUI

enum GlassTier: String, CaseIterable, Codable {
    case navigation
    case primaryAction
    case secondaryAction
    case ornamental
}

enum VisualIntensity: String, CaseIterable, Codable {
    case subtle
    case balanced
    case vivid
}

struct AppDesignSystem {
    struct Colors {
        let canvas = Color(red: 0.04, green: 0.06, blue: 0.11)
        let panel = Color(red: 0.09, green: 0.12, blue: 0.19)
        let accent = Color(red: 0.28, green: 0.86, blue: 0.98)
        let accentSoft = Color(red: 0.42, green: 0.95, blue: 0.76)
        let warning = Color(red: 0.89, green: 0.31, blue: 0.29)
        let success = Color(red: 0.30, green: 0.77, blue: 0.54)
    }

    struct Spacing {
        let xs: CGFloat = 6
        let sm: CGFloat = 10
        let md: CGFloat = 16
        let lg: CGFloat = 24
        let xl: CGFloat = 32
    }

    struct Radius {
        let card: CGFloat = 16
        let panel: CGFloat = 24
        let heroPrompt: CGFloat = 24
        let generationStage: CGFloat = 24
        let actionChip: CGFloat = 14
        let pill: CGFloat = 999
    }

    let colors = Colors()
    let spacing = Spacing()
    let radius = Radius()

    func glass(for tier: GlassTier, intensity: VisualIntensity, interactive: Bool = false) -> Glass {
        var base: Glass = .regular

        switch tier {
        case .navigation:
            base = .regular
        case .primaryAction:
            base = .regular.tint(colors.accent)
        case .secondaryAction:
            base = .regular.tint(colors.accentSoft)
        case .ornamental:
            base = .regular
        }

        let isInteractive = interactive && intensity != .subtle
        return isInteractive ? base.interactive(true) : base
    }
}

extension AppDesignSystem {
    static let cinematic = AppDesignSystem()
}
