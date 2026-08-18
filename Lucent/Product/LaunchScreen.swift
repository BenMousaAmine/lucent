//
//  LaunchScreen.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import SwiftUI

struct LaunchScreen: View {
    @State private var scanModel = ProductScanViewModel()
    @State private var wholeDiskModel = ScanViewModel()

    var body: some View {
        Group {
            if scanModel.state == .loaded {
                ProductResultsView(model: scanModel, scanModel: wholeDiskModel)
            } else {
                introBody
            }
        }
        .onAppear {
            scanModel.scan()
        }
    }

    private var introBody: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "internaldrive")
                .font(.system(size: 56))
                .foregroundStyle(LucentTheme.accent)
            Text("Lucent")
                .font(.largeTitle.bold())
            Text("Understands what's taking up space on your Mac, explaining every byte.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                bullet("magnifyingglass", "Analyzes Docker, Xcode, caches and more — always read-only.")
                bullet("checkmark.shield", "Never deletes anything without your decision.")
                bullet("folder.badge.questionmark", "It may ask for access to some folders: needed to see what's using space.")
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: 460)

            ProgressView()
                .padding(.top, 8)
            Text("Preparing…")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .frame(minWidth: 720, minHeight: 520)
    }

    private func bullet(_ icon: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(LucentTheme.accent).frame(width: 22)
            Text(text)
            Spacer()
        }
    }
}
