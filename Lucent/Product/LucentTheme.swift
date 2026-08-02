//
//  LucentTheme.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import SwiftUI

enum LucentTheme {

    // MARK: - Category colors (exact hex from the mockup's `catalog[].color`)

    static func color(for domain: Domain) -> Color {
        switch domain {
        case .docker: return Color(hex: 0x2B9BF4)
        case .packageManager, .nodeModules: return Color(hex: 0xF5A623)
        case .xcode: return Color(hex: 0x1E8FFF)
        case .system: return Color(hex: 0xBF5AF2)
        case .orphanApp: return Color(hex: 0xFF375F)
        case .unknown: return .secondary
        }
    }

    // MARK: - Risk tier colors (mockup `sevColor`)

    static func color(for risk: RiskTier) -> Color {
        switch risk {
        case .safe: return Color(hex: 0x32D74B)
        case .conditional: return Color(hex: 0xFFCE3A)
        case .doNotTouch: return Color(hex: 0xFF453A)
        }
    }

    static func label(for risk: RiskTier) -> LocalizedStringKey {
        switch risk {
        case .safe: return "Safe to remove"
        case .conditional: return "Needs review"
        case .doNotTouch: return "Caution"
        }
    }

    static let accent = Color(hex: 0x0A84FF)
    static let recoverableGreen = Color(hex: 0x32D74B)

    // MARK: - Typography (mockup uses SF Mono for all numeric/size figures)

    static func numeric(_ size: Font = .body) -> Font {
        size.monospaced()
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
