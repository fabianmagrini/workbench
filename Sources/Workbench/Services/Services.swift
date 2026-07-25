import Foundation

protocol AgentProvider: Sendable {
    var id: String { get }
    var name: String { get }

    func execute(task: TaskSnapshot) async -> AsyncThrowingStream<AgentEvent, Error>
    func cancel(taskID: UUID) async
}

struct TaskSnapshot: Sendable {
    let id: UUID
    let title: String
    let prompt: String
    let repositoryPath: String
}

enum AgentEvent: Sendable {
    case log(LogLevel, String)
    case changedFile(String)
    case requiresApproval(String)
    case finished(exitCode: Int)
}

actor PreviewAgentProvider: AgentProvider {
    let id = "preview"
    let name = "Codex"

    private var cancelledTasks: Set<UUID> = []

    func execute(task: TaskSnapshot) async -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Swift.Task {
                let events: [AgentEvent] = [
                    .log(.info, "Opening repository at \(task.repositoryPath)"),
                    .log(.info, "Reading project context"),
                    .log(.success, "Created an execution plan"),
                    .changedFile("Sources/Workbench/App/WorkbenchApp.swift"),
                    .log(.info, "Applying requested changes"),
                    .changedFile("Sources/Workbench/Features/Tasks/TaskDetailView.swift"),
                    .log(.success, "Changes compiled successfully"),
                    .finished(exitCode: 0)
                ]

                for event in events {
                    try? await Task.sleep(for: .milliseconds(550))
                    if isCancelled(task.id) {
                        continuation.finish()
                        return
                    }
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
    }

    func cancel(taskID: UUID) async {
        cancelledTasks.insert(taskID)
    }

    private func isCancelled(_ taskID: UUID) -> Bool {
        cancelledTasks.contains(taskID)
    }
}

protocol GitService: Sendable {
    func branch(at repositoryPath: String) async throws -> String
    func changedFiles(at repositoryPath: String) async throws -> [String]
}

actor LocalGitService: GitService {
    func branch(at repositoryPath: String) async throws -> String {
        try await runGit(arguments: ["branch", "--show-current"], at: repositoryPath)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func changedFiles(at repositoryPath: String) async throws -> [String] {
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
