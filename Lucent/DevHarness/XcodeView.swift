//
//  XcodeView.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import SwiftUI

struct XcodeView: View {
    @State private var model = XcodeViewModel()
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { onBack() } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless)
                Text("🛠️ Xcode").font(.title2.bold())
                Spacer()
            }
            .padding([.horizontal, .top])

            switch model.state {
            case .idle, .loading:
                VStack { Spacer(); ProgressView("Analisi di Xcode…"); Spacer() }
                    .frame(maxWidth: .infinity)
            case .unavailable:
                ContentUnavailableView(
                    "Xcode non trovato",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Nessuna cartella ~/Library/Developer/Xcode su questo Mac.")
                )
            case .loaded(let findings):
                if findings.isEmpty {
                    ContentUnavailableView("Niente da recuperare", systemImage: "checkmark.circle",
                                           description: Text("Xcode non ha spazio recuperabile."))
                } else {
                    List(findings, id: \.id) { FindingRow(finding: $0) }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 460)
        .onAppear { if case .idle = model.state { model.analyze() } }
    }
}
