//
//  WholeDiskColumn.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import SwiftUI

struct WholeDiskColumn: View {
    let model: ScanViewModel

    var body: some View {
        switch model.phase {
        case .intro:
            VStack { Spacer(); ProgressView("Starting scan…"); Spacer() }
        case .scanning:
            scanningBody
        case .results:
            resultsBody
        }
    }

    private var scanningBody: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().controlSize(.large)
            Text("Scanning…").font(.headline)
            HStack(spacing: 32) {
                stat("\(model.filesSeen)", "files")
                stat(model.bytesText, "used")
                stat("\(model.skippedPaths)", "skipped")
            }
            Text(model.currentPath.isEmpty ? " " : model.currentPath)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            Spacer()
        }
        .padding()
    }

    private var resultsBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Button { model.goBack() } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless)
                    .disabled(!model.canGoBack)
                Text(model.currentRoot?.path ?? "/")
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.head)
                Spacer()
                Text(summaryText).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal).padding(.top).padding(.bottom, 6)

            if model.skippedPaths > 100 {
                Label("Many paths skipped due to permissions. Enable Full Disk Access in Settings → Privacy.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal).padding(.bottom, 6)
            }

            Divider()

            List(model.children) { child in
                HStack {
                    Image(systemName: child.isDirectory ? "folder.fill" : "doc.fill")
                        .foregroundStyle(child.isDirectory ? AnyShapeStyle(LucentTheme.accent) : AnyShapeStyle(.secondary))
                    Text(child.name)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: child.physicalTotal, countStyle: .file))
                        .font(LucentTheme.numeric(.body)).foregroundStyle(.secondary)
                    if child.isDirectory {
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { model.enter(child) }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Whole disk")
    }

    private var summaryText: String {
        var s = "\(model.bytesText) · \(model.filesSeen) \(String(localized: "files"))"
        if model.skippedPaths > 0 { s += " · \(model.skippedPaths) \(String(localized: "skipped"))" }
        return s
    }

    private func stat(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
