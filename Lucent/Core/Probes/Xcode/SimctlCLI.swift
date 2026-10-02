import Foundation

protocol SimctlCommandRunner: Sendable {
    func run(_ args: [String]) throws -> Data
}

enum SimctlError: Error, Equatable {
    case commandFailed(args: [String], stderr: String)
}

struct SimctlCommandLineRunner: SimctlCommandRunner {

    func run(_ args: [String]) throws -> Data {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        proc.arguments = ["simctl"] + args
        let out = Pipe(), err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        try proc.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()

        guard proc.terminationStatus == 0 else {
            throw SimctlError.commandFailed(args: args, stderr: String(decoding: errData, as: UTF8.self))
        }
        return data
    }
}
