//
//  OrphanAppViewModel.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class OrphanAppViewModel {

    enum State {
        case idle
        case loading
        case loaded([Finding])
    }

    var state: State = .idle

    func analyze() {
        state = .loading
        Task {
            let probe = OrphanAppProbe()
            let findings = (try? await probe.scan()) ?? []
            self.state = .loaded(findings)
        }
    }
}
