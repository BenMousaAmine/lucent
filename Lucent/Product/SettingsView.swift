//
//  SettingsView.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import SwiftUI

struct SettingsView: View {
    @Bindable var settings: LucentSettings

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $settings.appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker("Glass", selection: $settings.glass) {
                    ForEach(GlassMaterial.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Layout") {
                Picker("Density", selection: $settings.density) {
                    ForEach(LayoutDensity.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Language") {
                Picker("Language", selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 300)
    }
}
