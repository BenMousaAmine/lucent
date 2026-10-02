//
//  WholeDiskColumn.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import SwiftUI

struct WholeDiskColumn: View {
    let model: ScanViewModel
    @Environment(DeletionController.self) private var deletion
    @State private var pendingTrash: ChildTotal?
    @State private var trashError: String?

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
                Button { model.rescan() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .help("Rescan")
            }
            .padding(.horizontal).padding(.top).padding(.bottom, 6)

            if let trashError {
                Label(trashError, systemImage: "xmark.octagon")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal).padding(.bottom, 6)
            }

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
                .contextMenu {
                    if let url = model.url(for: child), deletion.canTrash(url) {
                        Button("Move to Trash…", role: .destructive) { pendingTrash = child }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .confirmationDialog("Move to Trash?", isPresented: Binding(
                get: { pendingTrash != nil },
                set: { if !$0 { pendingTrash = nil } }
            ), titleVisibility: .visible, presenting: pendingTrash) { child in
                Button("Move to Trash", role: .destructive) { trash(child) }
                Button("Cancel", role: .cancel) {}
            } message: { child in
                Text("\(child.name) (\(ByteCountFormatter.string(fromByteCount: child.physicalTotal, countStyle: .file))) will be moved to the Trash. Lucent doesn't know what it's used for, so check before confirming. The space returns to macOS when you empty the Trash.")
            }
        }
        .navigationTitle("Whole disk")
    }

    private var summaryText: String {
        var s = "\(model.bytesText) · \(model.filesSeen) \(String(localized: "files"))"
        if model.skippedPaths > 0 { s += " · \(model.skippedPaths) \(String(localized: "skipped"))" }
        if let scannedAt = model.scannedAt {
            s += " · \(String(localized: "scanned \(scannedAt.formatted(.relative(presentation: .named)))"))"
        }
        return s
    }

    private func trash(_ child: ChildTotal) {
        guard let url = model.url(for: child) else { return }
        if deletion.trash(url, physicalSize: child.physicalTotal) {
            model.remove(child)
            trashError = nil
        } else {
            trashError = deletion.lastError
        }
    }

    private func stat(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
