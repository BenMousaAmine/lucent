//
//  ProductResultsView.swift
//  Lucent
//
//  Created by Amine ben moussa on 29/07/26.
//

import SwiftUI

struct ProductResultsView: View {
    let model: ProductScanViewModel
    let scanModel: ScanViewModel
    @State private var selectedItem: SidebarItem? = .wholeDisk
    @State private var selectedCategory: FindingCategory?
    @State private var selectedFinding: Finding?

    private var selectedDomain: Domain? {
        if case .domain(let d) = selectedItem { return d }
        return nil
    }

    private var categoriesForSelectedDomain: [FindingCategory] {
        guard let selectedDomain else { return [] }
        return model.categories(for: selectedDomain)
    }

    var body: some View {
        NavigationSplitView {
            DomainSidebar(model: model, selection: $selectedItem)
        } content: {
            switch selectedItem {
            case .wholeDisk, nil:
                WholeDiskColumn(model: scanModel)
            case .domain:
                List(categoriesForSelectedDomain, selection: $selectedCategory) { category in
                    CategorySummaryRow(category: category).tag(category)
                }
                .scrollContentBackground(.hidden)
                .navigationTitle(selectedDomain.map { domainLabel($0) } ?? "Findings")
            }
        } detail: {
            if let selectedCategory {
                CategoryDetailColumn(category: selectedCategory, selectedFinding: $selectedFinding)
            } else if case .domain = selectedItem {
                ContentUnavailableView("No selection", systemImage: "doc.text.magnifyingglass",
                                       description: Text("Select a category from the list to see its items."))
            } else {
                ContentUnavailableView("Overview", systemImage: "internaldrive",
                                       description: Text("Select a category to see the honest details of each item."))
            }
        }
        .frame(minWidth: 900, minHeight: 560)
        .onChange(of: selectedItem) { _, _ in
            selectedCategory = nil
            selectedFinding = nil
        }
    }

    private func domainLabel(_ domain: Domain) -> LocalizedStringKey {
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

private struct CategorySummaryRow: View {
    @Environment(LucentSettings.self) private var settings
    @Environment(DeletionController.self) private var deletion
    let category: FindingCategory

    private var liveFindings: [Finding] {
        category.findings.filter { !deletion.isDeleted($0) }
    }

    var body: some View {
        HStack {
            Circle()
                .fill(LucentTheme.color(for: category.risk))
                .frame(width: 9, height: 9)
            Text(FindingLabels.kindLabel(category.findings.first!))
            Spacer()
            Text("\(liveFindings.count)").font(.caption).foregroundStyle(.tertiary)
            Text(FindingLabels.reclaimText(bucketedReclaimable))
                .font(LucentTheme.numeric(.body))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, settings.density.rowVerticalPadding)
    }

    private var bucketedReclaimable: Reclaimable {
        let liveBytes = liveFindings.reduce(0) { $0 + $1.reclaimable.bytes }
        switch category.findings.first?.reclaimable {
        case .returnedToOS: return .returnedToOS(liveBytes)
        case .blockedBySnapshot: return .blockedBySnapshot(liveBytes)
        case .zero(let reason): return .zero(reason: reason)
        default: return .freedInContainerOnly(liveBytes)
        }
    }
}

private struct CategoryDetailColumn: View {
    @Environment(LucentSettings.self) private var settings
    let category: FindingCategory
    @Binding var selectedFinding: Finding?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(FindingLabels.kindLabel(category.findings.first!))
                .font(.title2.bold())
                .padding(settings.density.panelPadding)

            Divider()

            List(category.findings, id: \.id, selection: $selectedFinding) { finding in
                FindingElementRow(finding: finding).tag(finding)
            }
            .scrollContentBackground(.hidden)
            .frame(minHeight: 160, maxHeight: 260)

            Divider()

            if let selectedFinding {
                FindingDetailPanel(finding: selectedFinding)
            } else {
                ContentUnavailableView("No selection", systemImage: "doc.text.magnifyingglass",
                                       description: Text("Select an item to see its details."))
            }
        }
        .onChange(of: category) { _, _ in selectedFinding = nil }
    }
}

private struct FindingElementRow: View {
    @Environment(LucentSettings.self) private var settings
    @Environment(DeletionController.self) private var deletion
    let finding: Finding

    private var isDeleted: Bool { deletion.isDeleted(finding) }

    var body: some View {
        HStack {
            Circle()
                .fill(LucentTheme.color(for: finding.risk))
                .frame(width: 9, height: 9)
            Text(FindingLabels.title(finding))
            Spacer()
            Text(FindingLabels.reclaimText(finding.reclaimable))
                .font(LucentTheme.numeric(.body))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, settings.density.rowVerticalPadding)
        .strikethrough(isDeleted)
        .opacity(isDeleted ? 0.45 : 1)
    }
}
