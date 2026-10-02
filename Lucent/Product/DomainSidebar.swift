//
//  DomainSidebar.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import SwiftUI

struct DomainSidebar: View {
    @Environment(DeletionController.self) private var deletion
    let model: ProductScanViewModel
    let trash: TrashViewModel
    @Binding var selection: SidebarItem?

    /// Mirrors what the category list shows: deleted findings stop counting.
    private func liveBytes(for domain: Domain) -> Int64 {
        model.findings(for: domain)
            .filter { !deletion.isDeleted($0) }
            .reduce(0) { $0 + $1.reclaimable.bytes }
    }

    var body: some View {
        List(selection: $selection) {
            HStack {
                Image(systemName: "internaldrive")
                    .foregroundStyle(.tint)
                    .frame(width: 20)
                Text("Whole disk")
            }
            .tag(SidebarItem.wholeDisk)

            HStack {
                Image(systemName: "trash")
                    .foregroundStyle(.tint)
                    .frame(width: 20)
                Text("Trash")
                Spacer()
                if case .loaded = trash.state {
                    Text(ByteCountFormatter.string(fromByteCount: trash.totalBytes, countStyle: .file))
                        .font(LucentTheme.numeric(.callout))
                        .foregroundStyle(.secondary)
                }
            }
            .tag(SidebarItem.trash)

            Section("Categories") {
                ForEach(model.sortedDomains, id: \.self) { domain in
                    HStack {
                        Image(systemName: icon(for: domain))
                            .foregroundStyle(LucentTheme.color(for: domain))
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(label(for: domain))
                            if domain == .docker, let bytes = model.dockerDiskBytes {
                                Text("\(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)) on disk")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: liveBytes(for: domain), countStyle: .file))
                            .font(LucentTheme.numeric(.callout))
                            .foregroundStyle(.secondary)
                    }
                    .tag(SidebarItem.domain(domain))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Lucent")
    }

    private func icon(for domain: Domain) -> String {
        switch domain {
        case .docker: return "shippingbox"
        case .xcode: return "hammer"
        case .packageManager: return "shippingbox.and.arrow.backward"
        case .nodeModules: return "shippingbox.and.arrow.backward"
        case .orphanApp: return "app.dashed"
        case .devTools: return "wrench.and.screwdriver"
        case .system: return "internaldrive.fill"
        case .unknown: return "questionmark.folder"
        }
    }

    private func label(for domain: Domain) -> LocalizedStringKey {
        switch domain {
        case .docker: return "Docker"
        case .xcode: return "Xcode"
        case .packageManager: return "Package manager"
        case .nodeModules: return "node_modules"
        case .orphanApp: return "Orphaned apps"
        case .devTools: return "Developer tools"
        case .system: return "System"
        case .unknown: return "Other"
        }
    }
}
