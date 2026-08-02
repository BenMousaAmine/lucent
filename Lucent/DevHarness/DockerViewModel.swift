//
//  DockerViewModel.swift
//  Lucent
//
//  Created by Amine ben moussa on 14/06/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class DockerViewModel {

    enum State {
        case idle
        case loading
        case unavailable
        case loaded([Finding])
    }

    var state: State = .idle

    func analyze() {
        state = .loading
        Task {
            let probe = DockerProbe()
            guard await probe.isAvailable() else {
                self.state = .unavailable
                return
            }
            do {
                let findings = try await probe.scan()
                self.state = .loaded(findings)
            } catch {
                self.state = .unavailable
            }
        }
    }
}
