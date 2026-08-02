//
//  PrivilegedDeletionClient.swift
//  Lucent
//
//  Created by Amine ben moussa on 31/07/26.
//

import Foundation
import ServiceManagement

@MainActor
final class PrivilegedDeletionClient {

    private static let daemonPlistName = "it.fenix.lucent.LucentHelper.plist"
    private static let machServiceName = "it.fenix.lucent.LucentHelper"

    private var connection: NSXPCConnection?

    func registerIfNeeded() throws {
        let service = SMAppService.daemon(plistName: Self.daemonPlistName)
        guard service.status != .enabled else { return }
        try service.register()
    }

    func removeViaHelper(_ plan: DeletionPlan,
                         reply: @escaping (_ removed: [String],
                                           _ refused: [String],
                                           _ reasons: [String]) -> Void) {
        let wire = DeletionWire.encode(plan)
        let proxy = makeProxy { _, _, _ in
            reply([], wire.paths, wire.paths.map { _ in "helper connection failed" })
        }
        proxy?.removePaths(wire.paths, strategyRawValues: wire.strategies, reply: reply)
    }

    // MARK: - Private

    private func makeProxy(
        onError: @escaping (_ removed: [String], _ refused: [String], _ reasons: [String]) -> Void
    ) -> DeletionServiceProtocol? {
        let conn = connection ?? NSXPCConnection(machServiceName: Self.machServiceName,
                                                 options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: DeletionServiceProtocol.self)
        conn.resume()
        connection = conn
        return conn.remoteObjectProxyWithErrorHandler { _ in
            onError([], [], [])
        } as? DeletionServiceProtocol
    }
}
