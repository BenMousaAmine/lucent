//
//  LucentApp.swift
//  Lucent
//
//  Created by Amine ben moussa on 25/07/26.
//

import SwiftUI
import CoreData

@main
struct LucentApp: App {
    let persistenceController = PersistenceController.shared
    @State private var settings = LucentSettings()
    @State private var deletion = DeletionController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(settings)
                .environment(deletion)
                .preferredColorScheme(settings.appearance.colorScheme)
                .localeOverride(settings.language.locale)
        }
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView(settings: settings)
                .environment(settings)
                .localeOverride(settings.language.locale)
        }
    }
}

private extension View {
    @ViewBuilder
    func localeOverride(_ locale: Locale?) -> some View {
        if let locale {
            environment(\.locale, locale)
        } else {
            self
        }
    }
}
