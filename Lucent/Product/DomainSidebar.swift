//
//  DomainSidebar.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import SwiftUI

struct DomainSidebar: View {
    let model: ProductScanViewModel
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            HStack {
                Image(systemName: "internaldrive")
                    .foregroundStyle(.tint)
                    .frame(width: 20)
                Text("Whole disk")
            }
            .tag(SidebarItem.wholeDisk)

            Section("Categories") {
                ForEach(model.sortedDomains, id: \.self) { domain in
                    HStack {
                        Image(systemName: icon(for: domain))
                            .foregroundStyle(LucentTheme.color(for: domain))
                            .frame(width: 20)
                        Text(label(for: domain))
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: model.totalBytes(for: domain), countStyle: .file))
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
        case .system: return "System"
        case .unknown: return "Other"
        }
    }
}
