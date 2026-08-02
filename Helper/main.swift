//
//  main.swift
//  LucentHelper
//
//  Created by Amine ben moussa on 31/07/26.
//

import Foundation

let machServiceName = "it.fenix.lucent.LucentHelper"

final class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: DeletionServiceProtocol.self)
        connection.exportedObject = DeletionService()
        connection.resume()
        return true
    }
}

let delegate = ServiceDelegate()
let listener = NSXPCListener(machServiceName: machServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
