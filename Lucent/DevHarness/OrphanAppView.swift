//
//  OrphanAppView.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import SwiftUI

struct OrphanAppView: View {
    @State private var model = OrphanAppViewModel()
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { onBack() } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless)
                Text("👻 App orfane").font(.title2.bold())
                Spacer()
            }
            .padding([.horizontal, .top])

            switch model.state {
            case .idle, .loading:
                VStack { Spacer(); ProgressView("Ricerca app disinstallate…"); Spacer() }
                    .frame(maxWidth: .infinity)
            case .loaded(let findings):
                if findings.isEmpty {
                    ContentUnavailableView("Niente da recuperare", systemImage: "checkmark.circle",
                                           description: Text("Nessun residuo di app disinstallate trovato."))
                } else {
                    List(findings, id: \.id) { FindingRow(finding: $0) }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 460)
        .onAppear { if case .idle = model.state { model.analyze() } }
    }
}
