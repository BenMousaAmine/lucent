//
//  LucentSettings.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import SwiftUI
import Observation

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .system: return "Automatic"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

enum GlassMaterial: String, CaseIterable, Identifiable {
    case vibrant, frosted, clear
    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .vibrant: return "Vibrant"
        case .frosted: return "Frosted"
        case .clear:   return "Clear"
        }
    }

    var material: Material {
        switch self {
        case .vibrant: return .regularMaterial
        case .frosted: return .thickMaterial
        case .clear:   return .ultraThinMaterial
        }
    }
}

enum LayoutDensity: String, CaseIterable, Identifiable {
    case comfortable, compact
    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .comfortable: return "Comfortable"
        case .compact:     return "Compact"
        }
    }

    var rowVerticalPadding: CGFloat {
        self == .compact ? 2 : 6
    }

    var panelPadding: CGFloat {
        self == .compact ? 14 : 20
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, en, it, fr, es, zhHans = "zh-Hans", ar
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .en:     return "English"
        case .it:     return "Italiano"
        case .fr:     return "Français"
        case .es:     return "Español"
        case .zhHans: return "简体中文"
        case .ar:     return "العربية"
        }
    }

    var locale: Locale? {
        self == .system ? nil : Locale(identifier: rawValue)
    }
}

@MainActor
@Observable
final class LucentSettings {
    var appearance: AppearanceMode {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance) }
    }
    var glass: GlassMaterial {
        didSet { UserDefaults.standard.set(glass.rawValue, forKey: Keys.glass) }
    }
    var density: LayoutDensity {
        didSet { UserDefaults.standard.set(density.rawValue, forKey: Keys.density) }
    }
    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Keys.language) }
    }

    init() {
        let d = UserDefaults.standard
        appearance = AppearanceMode(rawValue: d.string(forKey: Keys.appearance) ?? "") ?? .system
        glass = GlassMaterial(rawValue: d.string(forKey: Keys.glass) ?? "") ?? .vibrant
        density = LayoutDensity(rawValue: d.string(forKey: Keys.density) ?? "") ?? .comfortable
        language = AppLanguage(rawValue: d.string(forKey: Keys.language) ?? "") ?? .system
    }

    private enum Keys {
        static let appearance = "lucent.appearance"
        static let glass = "lucent.glass"
        static let density = "lucent.density"
        static let language = "lucent.language"
    }
}
