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

enum SimctlJSON {
    static func decode(_ data: Data) -> SimctlDeviceList {
        (try? JSONDecoder().decode(SimctlDeviceList.self, from: data))
            ?? SimctlDeviceList(devices: [:])
    }
}
