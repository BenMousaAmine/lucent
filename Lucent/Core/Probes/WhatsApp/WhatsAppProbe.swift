import Foundation

struct WhatsAppProbe: DomainProbe {
    let domain: Domain = .system
    private let store: WhatsAppMediaStore
    private let minimumReportableSize: Int64
    private let manifest: RuleManifest

    init(store: WhatsAppMediaStore = WhatsAppMediaStore(),
         minimumReportableSize: Int64 = 10 * 1024 * 1024,
         manifest: RuleManifest = .default) {
        self.store = store
        self.minimumReportableSize = minimumReportableSize
        self.manifest = manifest
    }

    func isAvailable() async -> Bool { store.isPresent }

    func scan() async throws -> [Finding] {
        guard store.isReadable else { return [accessNeededFinding()] }
        let tier = manifest.resolved(domain: .system, kind: "whatsAppOrphanMedia",
                                     fallbackRisk: .safe, fallbackReversibility: .trash)
        return (store.orphanTotals() ?? [])
            .filter { $0.physicalSize >= minimumReportableSize }
            .map { total in
                let explanation = String(
                    localized: "\(total.fileCount) photos, videos and files from the chat \"\(total.name)\" that WhatsApp downloaded but no longer links to any message: you can't see them in the app, and its own storage screen doesn't count them. Lucent moves them to the Trash as one folder. Your messages and the media WhatsApp still shows are left untouched. Quit WhatsApp before removing them."
                )
                return Finding(
                    id: UUID(),
                    domain: .system,
                    kind: "whatsAppOrphanMedia",
                    nodes: [],
                    reclaimable: .returnedToOS(total.physicalSize),
                    owner: total.name,
                    state: .orphan,
                    risk: tier.risk,
                    reversibility: tier.reversibility,
                    explanation: explanation,
                    comesBack: false,
                    whatsAppOrphanChat: total.chatID
                )
            }
    }

    private func accessNeededFinding() -> Finding {
        Finding(
            id: UUID(),
            domain: .system,
            kind: "whatsAppAccessNeeded",
            nodes: [],
            reclaimable: .zero(reason: String(localized: "not readable")),
            owner: "WhatsApp",
            state: .unknown,
            risk: .conditional,
            reversibility: .trash,
            explanation: String(
                localized: "WhatsApp is installed, but macOS doesn't let Lucent read its data, so Lucent can't tell whether it keeps media no chat uses anymore. Enable Full Disk Access for Lucent in System Settings → Privacy & Security, then scan again."
            ),
            comesBack: nil
        )
    }
}
