import SwiftUI

enum LiquidGlassSurface: String, CaseIterable, Codable {
    case navigationBar
    case toolbar
    case primaryCTA
    case secondaryCTA
    case sidebarBadge
    case ornamentalChip
    case backgroundPanel
    case heroPromptCard
    case heroAccessoryControls
    case generationStageCard
    case generationStatusBadge
    case resultActionChip
}

struct LiquidGlassPolicy: Codable {
    var enabledCustomSurfaces: Set<LiquidGlassSurface>
    var useSystemBars: Bool
    var maximumVisibleCustomEffects: Int

    static let systemFirstPremium = LiquidGlassPolicy(
        enabledCustomSurfaces: [
            .primaryCTA,
            .secondaryCTA,
            .sidebarBadge,
            .ornamentalChip,
            .heroPromptCard,
            .heroAccessoryControls,
            .generationStageCard,
            .generationStatusBadge,
            .resultActionChip
        ],
        useSystemBars: true,
        maximumVisibleCustomEffects: 12
    )

    func allowsCustomGlass(on surface: LiquidGlassSurface) -> Bool {
        enabledCustomSurfaces.contains(surface)
    }

    func allowsCustomGlass(on surface: LiquidGlassSurface, slot: Int) -> Bool {
        allowsCustomGlass(on: surface) && slot < maximumVisibleCustomEffects
    }

    func glassTier(for surface: LiquidGlassSurface) -> GlassTier {
        switch surface {
        case .navigationBar, .toolbar:
            return .navigation
        case .primaryCTA:
            return .primaryAction
        case .secondaryCTA, .sidebarBadge, .generationStatusBadge, .resultActionChip:
            return .secondaryAction
        case .ornamentalChip, .backgroundPanel, .heroPromptCard, .heroAccessoryControls, .generationStageCard:
            return .ornamental
        }
    }

    func isInteractive(surface: LiquidGlassSurface) -> Bool {
        switch surface {
        case .primaryCTA, .secondaryCTA, .heroAccessoryControls, .resultActionChip:
            return true
        default:
            return false
        }
    }

    func tier(for surface: LiquidGlassSurface) -> GlassTier {
        glassTier(for: surface)
    }
}
