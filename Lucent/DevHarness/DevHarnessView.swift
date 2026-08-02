//
//  DevHarnessView.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import SwiftUI
import AppKit

struct DevHarnessView: View {
    @State private var model = ScanViewModel()
    @State private var showingDocker = false
    @State private var showingXcode = false
    @State private var showingPackageManager = false
    @State private var showingOrphanApps = false
    @State private var showingSystemCache = false

    var body: some View {
        VStack(spacing: 0) {
            if showingDocker {
                DockerView(onBack: { showingDocker = false })
            } else if showingXcode {
                XcodeView(onBack: { showingXcode = false })
            } else if showingPackageManager {
                PackageManagerView(onBack: { showingPackageManager = false })
            } else if showingOrphanApps {
                OrphanAppView(onBack: { showingOrphanApps = false })
            } else if showingSystemCache {
                SystemCacheView(onBack: { showingSystemCache = false })
            } else {
                switch model.phase {
                case .intro:    IntroScreen(model: model, showingDocker: $showingDocker, showingXcode: $showingXcode, showingPackageManager: $showingPackageManager, showingOrphanApps: $showingOrphanApps, showingSystemCache: $showingSystemCache)
                case .scanning: ScanningScreen(model: model)
                case .results:  ResultsScreen(model: model)
                }
            }
        }
        .frame(minWidth: 720, minHeight: 520)
    }
}

// MARK: - Intro

private struct IntroScreen: View {
    let model: ScanViewModel
    @Binding var showingDocker: Bool
    @Binding var showingXcode: Bool
    @Binding var showingPackageManager: Bool
    @Binding var showingOrphanApps: Bool
    @Binding var showingSystemCache: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "internaldrive")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Lucent")
                .font(.largeTitle.bold())
            Text("Capisci cosa occupa lo spazio sul tuo Mac.")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                bullet("magnifyingglass", "Scansiona il disco e misura lo spazio realmente occupato.")
                bullet("doc.text.magnifyingglass", "Mostra dove sta lo spazio, cartella per cartella.")
                bullet("checkmark.shield", "Sola lettura: non cancella nulla.")
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: 460)

            Button {
                model.start()
            } label: {
                Text("Scansiona il Mac")
                    .font(.headline)
                    .padding(.horizontal, 24).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)

            Button("Scegli una cartella…") { chooseFolder() }
                .buttonStyle(.link)

            Button {
                showingDocker = true
            } label: {
                Label("Analizza Docker", systemImage: "shippingbox")
                    .padding(.horizontal, 16).padding(.vertical, 6)
            }
            .buttonStyle(.bordered)

            Button {
                showingXcode = true
            } label: {
                Label("Analizza Xcode", systemImage: "hammer")
                    .padding(.horizontal, 16).padding(.vertical, 6)
            }
            .buttonStyle(.bordered)

            Button {
                showingPackageManager = true
            } label: {
                Label("Analizza Package Manager", systemImage: "shippingbox.and.arrow.backward")
                    .padding(.horizontal, 16).padding(.vertical, 6)
            }
            .buttonStyle(.bordered)

            Button {
                showingOrphanApps = true
            } label: {
                Label("App orfane", systemImage: "app.dashed")
                    .padding(.horizontal, 16).padding(.vertical, 6)
            }
            .buttonStyle(.bordered)

            Button {
                showingSystemCache = true
            } label: {
                Label("Analizza System", systemImage: "internaldrive.fill")
                    .padding(.horizontal, 16).padding(.vertical, 6)
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(.tint).frame(width: 22)
            Text(text)
            Spacer()
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            model.start(root: url)
        }
    }
}

// MARK: - Scanning

private struct ScanningScreen: View {
    let model: ScanViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .scaleEffect(1.6)
                .padding(.bottom, 8)

            Text("Scansione in corso…")
                .font(.title2.bold())

            HStack(spacing: 40) {
                stat("\(model.filesSeen)", "file")
                stat(model.bytesText, "occupati")
                stat("\(model.skippedPaths)", "saltati")
            }

            Text(model.currentPath.isEmpty ? " " : model.currentPath)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: 520)

            Button("Annulla") { model.cancel() }
                .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Results

private struct ResultsScreen: View {
    let model: ScanViewModel

    private var maxBytes: Int64 { model.children.map(\.physicalTotal).max() ?? 1 }

    private var summaryText: String {
        var s = "\(model.bytesText) occupati · \(model.filesSeen) file"
        if model.skippedPaths > 0 { s += " · \(model.skippedPaths) saltati" }
        return s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Dove sta lo spazio")
                        .font(.title2.bold())
                    Text(summaryText)
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Nuova scansione") { model.reset() }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal).padding(.top)

            HStack(spacing: 6) {
                Button {
                    model.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(!model.canGoBack)

                Text(model.currentRoot?.path ?? "/")
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.head)
                Spacer()
            }
            .padding(.horizontal).padding(.vertical, 6)

            if model.skippedPaths > 100 {
                Label("Molti percorsi saltati per permessi. Abilita Full Disk Access in Impostazioni → Privacy per vedere tutto.",
                      systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .padding(.horizontal).padding(.bottom, 8)
                    .foregroundStyle(.orange)
            }

            Divider()

            List(model.children) { child in
                HStack {
                    Image(systemName: child.isDirectory ? "folder.fill" : "doc.fill")
                        .foregroundStyle(child.isDirectory ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    Text(child.name)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: child.physicalTotal, countStyle: .file))
                        .monospacedDigit().foregroundStyle(.secondary)
                    if child.isDirectory {
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { model.enter(child) }
                .overlay(alignment: .bottomLeading) {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.tint.opacity(0.15))
                            .frame(width: geo.size.width * barFraction(child.physicalTotal))
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
    }

    private func barFraction(_ bytes: Int64) -> CGFloat {
        guard maxBytes > 0 else { return 0 }
        return CGFloat(Double(bytes) / Double(maxBytes))
    }
}

#Preview {
    DevHarnessView()
}
