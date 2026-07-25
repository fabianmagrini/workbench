import Foundation
#if SWIFT_PACKAGE
import WorkbenchCore
#endif

public protocol AgentProvider: Sendable {
    var id: String { get }
    var name: String { get }

    func execute(task: TaskSnapshot) async -> AsyncThrowingStream<AgentEvent, Error>
    func cancel(taskID: UUID) async
}

public struct TaskSnapshot: Sendable {
    public let id: UUID
    public let title: String
    public let prompt: String
    public let repositoryPath: String

    public init(id: UUID, title: String, prompt: String, repositoryPath: String) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.repositoryPath = repositoryPath
    }
}

public enum AgentEvent: Sendable {
    case log(LogLevel, String)
    case changedFile(String)
    case requiresApproval(String)
    case finished(exitCode: Int)
}

public actor PreviewAgentProvider: AgentProvider {
    public let id = "preview"
    public let name = "Codex"

    private var cancelledTasks: Set<UUID> = []

    public init() {}

    public func execute(task: TaskSnapshot) async -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Swift.Task {
                let events: [AgentEvent] = [
                    .log(.info, "Opening repository at \(task.repositoryPath)"),
                    .log(.info, "Reading project context"),
                    .log(.success, "Created an execution plan"),
                    .changedFile("Sources/WorkbenchApp/WorkbenchApp.swift"),
                    .log(.info, "Applying requested changes"),
                    .changedFile("Sources/WorkbenchUI/Features/Tasks/TaskViews.swift"),
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

    public func cancel(taskID: UUID) async {
        cancelledTasks.insert(taskID)
    }

    private func isCancelled(_ taskID: UUID) -> Bool {
        cancelledTasks.contains(taskID)
    }
}
