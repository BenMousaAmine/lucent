import Foundation

struct SimulatorDeletionService {

    private let runner: SimctlCommandRunner

    init(runner: SimctlCommandRunner = SimctlCommandLineRunner()) {
        self.runner = runner
    }

    static func arguments(for resource: SimulatorResource) -> [String] {
        switch resource {
        case .runtime(let identifier): return ["runtime", "delete", identifier]
        case .unavailableDevices:      return ["delete", "unavailable"]
        }
    }

    func remove(_ resource: SimulatorResource) throws {
        _ = try runner.run(Self.arguments(for: resource))
    }
}
