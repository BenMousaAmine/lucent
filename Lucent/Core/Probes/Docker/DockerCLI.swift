//
//  DockerCLI.swift
//  Lucent
//
//  Created by Amine ben moussa on 02/06/26.
//

import Foundation

protocol DockerCommandRunner: Sendable {
    func run(_ args: [String]) throws -> Data

    func runLong(_ args: [String]) async throws
}

extension DockerCommandRunner {
    func runLong(_ args: [String]) async throws {
        _ = try run(args)
    }
}

enum DockerCLIError: Error, Equatable {
    case dockerNotFound
    case commandFailed(args: [String], status: Int32, stderr: String)
}

struct DockerCommandLineRunner: DockerCommandRunner {

    private static let candidatePaths = [
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        "/usr/bin/docker",
    ]

    private func dockerPath() -> String? {
        Self.candidatePaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func run(_ args: [String]) throws -> Data {
        guard let path = dockerPath() else { throw DockerCLIError.dockerNotFound }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        let out = Pipe(), err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        try proc.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()

        guard proc.terminationStatus == 0 else {
            throw DockerCLIError.commandFailed(
                args: args,
                status: proc.terminationStatus,
                stderr: String(decoding: errData, as: UTF8.self)
            )
        }
        return data
    }

    func runLong(_ args: [String]) async throws {
        guard let path = dockerPath() else { throw DockerCLIError.dockerNotFound }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        let err = Pipe()
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = err
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            proc.terminationHandler = { _ in continuation.resume() }
            do {
                try proc.run()
            } catch {
                proc.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }

        guard proc.terminationStatus == 0 else {
            throw DockerCLIError.commandFailed(
                args: args,
                status: proc.terminationStatus,
                stderr: String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            )
        }
    }
}
