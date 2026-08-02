//
//  ContentView.swift
//  Lucent
//
//  Created by Amine ben moussa on 25/07/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(LucentSettings.self) private var settings

    var body: some View {
        LaunchScreen()
            .containerBackground(settings.glass.material, for: .window)
    }
}

#Preview {
    ContentView()
        .environment(LucentSettings())
        .environment(DeletionController())
}
