//
//  SnapshotInspectorTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 02/06/26.
//

import Testing
import Foundation
@testable import Lucent

struct SnapshotInspectorTests {

    @Test("SnapshotInspector returns an empty list on a volume with no snapshots")
    func emptyVolumeHasNoSnapshots() throws {
        let volume = try DisposableAPFSVolume()
        defer { volume.destroy() }

        let snapshots = try SnapshotInspector().snapshots(forVolumeAt: volume.mountPoint)
        #expect(snapshots.isEmpty)
    }
}
