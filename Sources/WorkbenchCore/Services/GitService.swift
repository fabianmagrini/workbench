import Foundation

public protocol GitService: Sendable {
    func branch(at repositoryPath: String) async throws -> String
    func changedFiles(at repositoryPath: String) async throws -> [String]
}

public actor LocalGitService: GitService {
    public init() {}

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
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", path] + arguments
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            throw CocoaError(.fileReadUnknown)
        }
        return String(decoding: data, as: UTF8.self)
    }
}
