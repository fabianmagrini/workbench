import Foundation

public protocol GitService: Sendable {
    func branch(at repositoryPath: String) async throws -> String
    func changedFiles(at repositoryPath: String) async throws -> [String]
}

public struct GitCommandError: Error, Sendable, Equatable {
    public let arguments: [String]
    public let exitCode: Int32
    public let standardError: String

    public init(arguments: [String], exitCode: Int32, standardError: String) {
        self.arguments = arguments
        self.exitCode = exitCode
        self.standardError = standardError
    }
}

public actor LocalGitService: GitService {
    private let processRunner: any ProcessRunner

    public init(processRunner: any ProcessRunner = LocalProcessRunner()) {
        self.processRunner = processRunner
    }

    public func branch(at repositoryPath: String) async throws -> String {
        try await runGit(arguments: ["branch", "--show-current"], at: repositoryPath)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func changedFiles(at repositoryPath: String) async throws -> [String] {
        let output = try await runGit(arguments: ["status", "--short"], at: repositoryPath)
        return output.split(separator: "\n").map {
            String($0.dropFirst(min(3, $0.count)))
        }
    }

    private func runGit(arguments: [String], at path: String) async throws -> String {
        let commandArguments = ["-C", path] + arguments
        let result = try await processRunner.run(
            ProcessRequest(
                executableURL: URL(fileURLWithPath: "/usr/bin/git"),
                arguments: commandArguments
            )
        )
        guard result.exitCode == 0 else {
            throw GitCommandError(
                arguments: commandArguments,
                exitCode: result.exitCode,
                standardError: result.standardErrorString
            )
        }
        return result.standardOutputString
    }
}
