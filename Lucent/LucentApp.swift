//
//  LucentApp.swift
//  Lucent
//
//  Created by Amine ben moussa on 02/06/2026.
//

import SwiftUI
import CoreData

@main
struct LucentApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
