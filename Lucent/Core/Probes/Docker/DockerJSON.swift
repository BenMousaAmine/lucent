//
//  DockerJSON.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import Foundation

struct DockerDfRow: Decodable {
    let type: String
    let TotalCount: String
    let Active: String
    let Size: String
    let Reclaimable: String

    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case TotalCount, Active, Size, Reclaimable
    }
}

struct DockerImageRow: Decodable {
    let ID: String
    let Repository: String
    let Tag: String
    let Size: String
    let Containers: String
}

struct DockerContainerRow: Decodable {
    let ID: String
    let Image: String
    let Names: String
    let State: String
    let Status: String
    let Size: String
}

struct DockerVolumeRow: Decodable {
    let Name: String
    let Driver: String
    let Labels: String
}

extension DockerImageRow {
    var displayName: String {
        Tag == "<none>" ? Repository : "\(Repository):\(Tag)"
    }
}
