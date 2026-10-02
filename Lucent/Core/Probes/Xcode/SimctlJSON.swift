//
//  SimctlJSON.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import Foundation

struct SimctlDevice: Decodable {
    let udid: String
    let name: String
    let state: String
    let dataPathSize: Int64?
    let isAvailable: Bool?
}

struct SimctlDeviceList: Decodable {
    let devices: [String: [SimctlDevice]]

    var allDevices: [SimctlDevice] { devices.values.flatMap { $0 } }
}

struct SimctlRuntime: Decodable {
    let identifier: String
    let build: String
    let version: String
    let runtimeIdentifier: String?
    let sizeBytes: Int64?
    let deletable: Bool?

    var platform: String {
        let name = runtimeIdentifier?.split(separator: ".").last?.split(separator: "-").first.map(String.init)
        return SimulatorRuntimeAsset.displayPlatform(name ?? "Simulator")
    }

    var displayName: String { "\(platform) \(version) (\(build))" }
}

enum SimctlJSON {
    static func decode(_ data: Data) -> SimctlDeviceList {
        (try? JSONDecoder().decode(SimctlDeviceList.self, from: data))
            ?? SimctlDeviceList(devices: [:])
    }

    static func decodeRuntimes(_ data: Data) -> [SimctlRuntime] {
        let byIdentifier = (try? JSONDecoder().decode([String: SimctlRuntime].self, from: data)) ?? [:]
        return byIdentifier.values.sorted { $0.displayName < $1.displayName }
    }
}
