import Foundation
import SwiftData
#if SWIFT_PACKAGE
import WorkbenchCore
#endif

@MainActor
public final class SessionOrchestrator {
    private let agentProvider: any AgentProvider
    private var runningJobs: [UUID: Swift.Task<Void, Never>] = [:]

    public init(agentProvider: any AgentProvider) {
        self.agentProvider = agentProvider
    }

    @discardableResult
    public func run(task: WorkbenchTask, context: ModelContext) -> AgentSession? {
        guard
            let workspace = task.workspace,
            runningJobs[task.id] == nil
        else { return nil }

        task.status = .running
        task.updatedAt = .now

        let session = AgentSession(agent: task.agent, status: .running, task: task)
        context.insert(session)
        try? context.save()

        let snapshot = TaskSnapshot(
            id: task.id,
            title: task.title,
            prompt: task.prompt,
            repositoryPath: workspace.repositoryPath
        )

        runningJobs[task.id] = Swift.Task { [weak self] in
            guard let self else { return }
            defer { runningJobs[task.id] = nil }

            do {
                let events = await agentProvider.execute(task: snapshot)
                for try await event in events {
                    guard !Swift.Task.isCancelled else { break }
                    apply(event, to: session, task: task, context: context)
                }
            } catch {
                task.status = .failed
                session.status = .failed
                context.insert(
                    LogEntry(level: .error, message: error.localizedDescription, session: session)
                )
            }
            try? context.save()
        }

        return session
    }

    public func cancel(task: WorkbenchTask, context: ModelContext) {
        runningJobs[task.id]?.cancel()
        runningJobs[task.id] = nil
        task.status = .cancelled
        task.updatedAt = .now

        if let session = task.sessions.last(where: { $0.status == .running }) ?? task.sessions.last {
            session.status = .cancelled
            session.finishedAt = .now
            context.insert(
                LogEntry(level: .warning, message: "Execution cancelled", session: session)
            )
        }

        Swift.Task { await agentProvider.cancel(taskID: task.id) }
        try? context.save()
    }

    public func isRunning(taskID: UUID) -> Bool {
        runningJobs[taskID] != nil
    }

    private func apply(
        _ event: AgentEvent,
        to session: AgentSession,
        task: WorkbenchTask,
        context: ModelContext
    ) {
        switch event {
        case let .log(level, message):
            context.insert(LogEntry(level: level, message: message, session: session))
        case let .changedFile(path):
            if !session.changedFiles.contains(path) {
                session.changedFiles.append(path)
            }
        case let .requiresApproval(message):
            task.status = .waitingApproval
            session.status = .waitingApproval
            context.insert(LogEntry(level: .warning, message: message, session: session))
        case let .finished(exitCode):
            session.exitCode = exitCode
            session.finishedAt = .now
            session.status = exitCode == 0 ? .completed : .failed
            task.status = session.status
        }
        task.updatedAt = .now
    }
}
