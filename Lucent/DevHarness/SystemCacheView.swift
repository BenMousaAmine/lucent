//
//  SystemCacheView.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import SwiftUI

struct SystemCacheView: View {
    @State private var model = SystemCacheViewModel()
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { onBack() } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless)
                Text("🗂️ System").font(.title2.bold())
                Spacer()
            }
            .padding([.horizontal, .top])

            switch model.state {
            case .idle, .loading:
                VStack { Spacer(); ProgressView("Analisi cache di sistema…"); Spacer() }
                    .frame(maxWidth: .infinity)
            case .loaded(let findings):
                if findings.isEmpty {
                    ContentUnavailableView("Niente da recuperare", systemImage: "checkmark.circle",
                                           description: Text("Nessuna cache di terze parti trovata."))
                } else {
                    List(findings, id: \.id) { FindingRow(finding: $0) }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 460)
        .onAppear { if case .idle = model.state { model.analyze() } }
    }
}
