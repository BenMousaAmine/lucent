//
//  DockerView.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import SwiftUI

struct DockerView: View {
    @State private var model = DockerViewModel()
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { onBack() } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless)
                Text("🐳 Docker").font(.title2.bold())
                Spacer()
            }
            .padding([.horizontal, .top])

            switch model.state {
            case .idle, .loading:
                VStack { Spacer(); ProgressView("Analisi di Docker…"); Spacer() }
                    .frame(maxWidth: .infinity)
            case .unavailable:
                ContentUnavailableView(
                    "Docker non disponibile",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Il daemon Docker non è raggiungibile. Avvialo e riprova.")
                )
            case .loaded(let findings):
                if findings.isEmpty {
                    ContentUnavailableView("Niente da recuperare", systemImage: "checkmark.circle",
                                           description: Text("Docker non ha spazio recuperabile."))
                } else {
                    List(findings, id: \.id) { FindingRow(finding: $0) }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 460)
        .onAppear { if case .idle = model.state { model.analyze() } }
    }
}

struct FindingRow: View {
    let finding: Finding
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tierBadge).font(.title3)
                VStack(alignment: .leading, spacing: 0) {
                    Text(FindingLabels.title(finding)).font(.headline)
                    if FindingLabels.title(finding) != kindLabel {
                        Text(kindLabel).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(reclaimText).monospacedDigit().foregroundStyle(.secondary)
            }
            Text(finding.explanation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(expanded ? nil : 2)
            Button(expanded ? "Mostra meno" : "Mostra di più") { expanded.toggle() }
                .buttonStyle(.link).font(.caption)
        }
        .padding(.vertical, 4)
    }

    private var tierBadge: String {
        switch finding.risk {
        case .safe: return "🟢"
        case .conditional: return "🟡"
        case .doNotTouch: return "🔴"
        }
    }

    private var kindLabel: String { FindingLabels.kindLabel(finding) }

    private var reclaimText: String { FindingLabels.reclaimText(finding.reclaimable) }
}
