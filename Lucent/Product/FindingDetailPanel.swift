//
//  FindingDetailPanel.swift
//  Lucent
//
//  Created by Amine ben moussa on 25/07/26.
//

import SwiftUI

struct FindingDetailPanel: View {
    @Environment(LucentSettings.self) private var settings
    @Environment(DeletionController.self) private var deletion
    let finding: Finding?
    @State private var confirming = false

    var body: some View {
        if let finding {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(LucentTheme.color(for: finding.risk))
                        .frame(width: 14, height: 14)
                    Text(FindingLabels.title(finding)).font(.title2.bold())
                    Spacer()
                    sevBadge
                }
                .padding(settings.density.panelPadding)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        row("Category", kindLabel)
                        numericRow("Reclaim", reclaimText)
                        if let owner = finding.owner, owner != FindingLabels.title(finding) {
                            row("Source", owner)
                        }
                        if let path = locationText { row("Location", path) }
                        row("State", stateText)
                        row("Reversibility", reversibilityText)
                        if let comesBack = finding.comesBack {
                            row("Comes back?", comesBack ? String(localized: "Yes, it regenerates") : String(localized: "No"))
                        }

                        Divider()

                        Text("Explanation")
                            .font(.headline)
                        Text(finding.explanation)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(settings.density.panelPadding)
                }

                actionSection(finding)
            }
        } else {
            ContentUnavailableView("No selection", systemImage: "doc.text.magnifyingglass",
                                   description: Text("Select an item from the list to see its details."))
        }
    }

    @ViewBuilder
    private func actionSection(_ finding: Finding) -> some View {
        if let result = deletion.result(for: finding) {
            Divider()
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(result.succeeded.first?.strategy == .quarantine
                     ? String(localized: "Moved to quarantine")
                     : String(localized: "Moved to Trash"))
                    .font(.callout)
                Spacer()
                Button(String(localized: "Undo")) { deletion.undo(finding) }
            }
            .padding(settings.density.panelPadding)
        } else if deletion.canDelete(finding) {
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Button(role: .destructive) {
                    confirming = true
                } label: {
                    Label(actionTitle(finding), systemImage: "trash")
                }
                .confirmationDialog(actionTitle(finding), isPresented: $confirming, titleVisibility: .visible) {
                    Button(actionTitle(finding), role: .destructive) { deletion.delete(finding) }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(confirmationMessage(finding))
                }
                if let error = deletion.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(settings.density.panelPadding)
        }
    }

    private func actionTitle(_ finding: Finding) -> String {
        finding.reversibility == .trash
            ? String(localized: "Move to Trash")
            : String(localized: "Move to quarantine")
    }

    private func confirmationMessage(_ finding: Finding) -> String {
        let reclaim = FindingLabels.reclaimText(finding.reclaimable)
        return finding.reversibility == .trash
            ? String(localized: "It goes to the Trash and is recoverable. Frees \(reclaim).")
            : String(localized: "It is moved to quarantine and can be restored. Frees \(reclaim).")
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.callout).foregroundStyle(.secondary).frame(width: 120, alignment: .leading)
            Text(value).font(.callout)
            Spacer()
        }
    }

    private func numericRow(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.callout).foregroundStyle(.secondary).frame(width: 120, alignment: .leading)
            Text(value).font(LucentTheme.numeric(.callout))
            Spacer()
        }
    }

    private var sevBadge: some View {
        let color = LucentTheme.color(for: finding!.risk)
        return Text(LucentTheme.label(for: finding!.risk))
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(color.opacity(0.4), lineWidth: 0.5))
    }

    private var kindLabel: String { FindingLabels.kindLabel(finding!) }

    /// Full path shown only when the Finding maps to a single directory,
    /// so project-level items can be told apart when names repeat.
    private var locationText: String? {
        guard let nodes = finding?.nodes, nodes.count == 1 else { return nil }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return nodes[0].path.path.replacingOccurrences(of: home, with: "~")
    }

    private var reclaimText: String { FindingLabels.reclaimText(finding!.reclaimable) }

    private var stateText: String {
        switch finding!.state {
        case .live: return String(localized: "Active")
        case .stale: return String(localized: "Not recent")
        case .orphan: return String(localized: "Orphaned")
        case .unknown: return String(localized: "Unknown")
        }
    }

    private var reversibilityText: String {
        switch finding!.reversibility {
        case .trash: return String(localized: "Trash (recoverable)")
        case .regenerable: return String(localized: "Regenerable (recreated on use)")
        case .permanent: return String(localized: "Permanent")
        }
    }
}
