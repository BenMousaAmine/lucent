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
                Text(doneText(finding, result)).font(.callout)
                Spacer()
                if deletion.canUndo(finding) {
                    Button(String(localized: "Undo")) { deletion.undo(finding) }
                }
            }
            .padding(settings.density.panelPadding)
        } else if deletion.isWorking(finding) {
            Divider()
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Working… this can take a minute.").font(.callout)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private func doneText(_ finding: Finding, _ result: DeletionResult) -> String {
        if finding.dockerResource == .reclaimSpace {
            return String(localized: "Docker's disk was compacted")
        }
        if finding.dockerResource != nil {
            return String(localized: "Removed from Docker")
        }
        if finding.simulatorResource != nil {
            return String(localized: "Removed from Xcode")
        }
        return result.succeeded.first?.strategy == .quarantine
            ? String(localized: "Moved to quarantine")
            : String(localized: "Moved to Trash")
    }

    private func actionTitle(_ finding: Finding) -> String {
        if finding.dockerResource == .reclaimSpace {
            return String(localized: "Compact Docker's disk")
        }
        if finding.dockerResource != nil {
            return String(localized: "Remove from Docker")
        }
        if finding.simulatorResource != nil {
            return String(localized: "Remove from Xcode")
        }
        return String(localized: "Move to Trash")
    }

    private func confirmationMessage(_ finding: Finding) -> String {
        let reclaim = FindingLabels.reclaimText(finding.reclaimable)
        if let resource = finding.dockerResource {
            return Self.dockerWarning(resource, name: finding.owner ?? "", reclaim: reclaim)
        }
        if let resource = finding.simulatorResource {
            return Self.simulatorWarning(resource, name: finding.owner ?? "", reclaim: reclaim)
        }
        return finding.reversibility == .permanent
            ? String(localized: "It goes to the Trash. It won't be recreated: once you empty the Trash it's gone for good. Frees \(reclaim).")
            : String(localized: "It goes to the Trash and is recoverable. Frees \(reclaim).")
    }

    /// Docker removals bypass the Trash entirely, so each message names the
    /// resource and states plainly that there is no way back.
    private static func dockerWarning(_ resource: DockerResource, name: String, reclaim: String) -> String {
        switch resource {
        case .image:
            return String(localized: "Permanently removes the image \"\(name)\" from Docker. There is no undo — you'd have to pull or build it again. Frees \(reclaim): Docker Desktop returns the space to macOS on its own when images are deleted.")
        case .container:
            return String(localized: "Permanently removes the container \"\(name)\" and its writable layer from Docker. There is no undo. Frees \(reclaim) inside Docker's VM; the space returns to macOS only after you compact Docker's disk.")
        case .volume:
            return String(localized: "WARNING: permanently removes the volume \"\(name)\" and everything stored in it — if it holds a database or other persistent data, that data is gone for good. There is no undo. Frees \(reclaim) inside Docker's VM; the space returns to macOS only after you compact Docker's disk.")
        case .reclaimSpace:
            return String(localized: "Runs Docker's own tool to give back to macOS the space already freed inside Docker. Nothing is deleted. Docker must be running, and the first time it downloads a small helper image. It can take a minute.")
        case .buildCache:
            return String(localized: "Permanently removes Docker's entire build cache. There is no undo, and later builds will be slower until it rebuilds. Frees \(reclaim) inside Docker's VM; the space returns to macOS only after you compact Docker's disk.")
        }
    }

    private static func simulatorWarning(_ resource: SimulatorResource, name: String, reclaim: String) -> String {
        switch resource {
        case .runtime:
            return String(localized: "Permanently removes \(name) from Xcode. There is no undo — you'd have to download it again from Xcode → Settings → Components. Frees \(reclaim).")
        case .unavailableDevices:
            return String(localized: "Permanently removes the simulators that can no longer start, with the apps and data inside them. There is no undo. Frees \(reclaim).")
        }
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
