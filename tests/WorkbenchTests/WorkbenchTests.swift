import Foundation
import SwiftData
import Testing
@testable import WorkbenchAgents
@testable import WorkbenchCore
@testable import WorkbenchUI

@Suite("Domain models")
struct DomainModelTests {
    @Test func taskStatusRawValuesRemainStable() {
        #expect(TaskStatus.running.rawValue == "Running")
        #expect(TaskStatus.waitingApproval.rawValue == "Waiting Approval")
        #expect(TaskStatus.completed.rawValue == "Completed")
    }

    @Test func allTaskPrioritiesAreExposed() {
        #expect(TaskPriority.allCases == [.low, .medium, .high])
    }

    @Test @MainActor func relationshipsPersistInMemory() throws {
        let container = try TestStore.makeContainer()
        let context = container.mainContext
        let workspace = Workspace(name: "API", repositoryPath: "/tmp/api")
        let task = WorkbenchTask(
            title: "Refresh tokens",
            prompt: "Implement token rotation",
            agent: "Codex",
            workspace: workspace
        )
        let session = AgentSession(agent: "Codex", task: task)
        let log = LogEntry(level: .success, message: "Complete", session: session)

        context.insert(workspace)
        context.insert(task)
        context.insert(session)
        context.insert(log)
        try context.save()

        let storedTasks = try context.fetch(FetchDescriptor<WorkbenchTask>())
        let storedSessions = try context.fetch(FetchDescriptor<AgentSession>())

        #expect(storedTasks.count == 1)
        #expect(storedTasks.first?.workspace?.name == "API")
        #expect(storedSessions.first?.task?.title == "Refresh tokens")
        #expect(storedSessions.first?.logs.first?.message == "Complete")
    }
}

@Suite("Application model")
struct AppModelTests {
    @Test @MainActor func seedIsIdempotent() throws {
        let container = try TestStore.makeContainer()
        let context = container.mainContext
        let model = AppModel(agentProvider: ImmediateAgentProvider())

        model.seedIfNeeded(context: context, workspaces: [])
        let firstWorkspaces = try context.fetch(FetchDescriptor<Workspace>())
        model.seedIfNeeded(context: context, workspaces: firstWorkspaces)

        #expect(try context.fetchCount(FetchDescriptor<Workspace>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<WorkbenchTask>()) == 4)
        #expect(model.selectedWorkspace?.name == "Workbench")
        #expect(model.selectedTask?.title == "Build task console")
    }

    @Test @MainActor func createTaskSelectsAndPersistsQueuedTask() throws {
        let container = try TestStore.makeContainer()
        let context = container.mainContext
        let workspace = Workspace(name: "Workbench", repositoryPath: "/tmp/workbench")
        context.insert(workspace)

        let model = AppModel(agentProvider: ImmediateAgentProvider())
        model.selectedWorkspace = workspace
        model.createTask(
            title: "Add approvals",
            prompt: "Implement the approval workflow",
            agent: "Codex",
            priority: .high,
            context: context
        )

        let tasks = try context.fetch(FetchDescriptor<WorkbenchTask>())
        #expect(tasks.count == 1)
        #expect(tasks[0].status == .queued)
        #expect(tasks[0].priority == .high)
        #expect(tasks[0].workspace?.id == workspace.id)
        #expect(model.selectedTask?.id == tasks[0].id)
    }

    @Test @MainActor func streamedEventsCompleteTaskAndSession() async throws {
        let container = try TestStore.makeContainer()
        let context = container.mainContext
        let workspace = Workspace(name: "Workbench", repositoryPath: "/tmp/workbench")
        let task = WorkbenchTask(
            title: "Build console",
            prompt: "Build it",
            agent: "Test Agent",
            status: .queued,
            workspace: workspace
        )
        context.insert(workspace)
        context.insert(task)

        let model = AppModel(agentProvider: ImmediateAgentProvider())
        model.selectedWorkspace = workspace
        model.selectedTask = task
        model.runSelectedTask(context: context)

        try await eventually { task.status == .completed }

        #expect(task.sessions.count == 1)
        #expect(task.sessions[0].status == .completed)
        #expect(task.sessions[0].exitCode == 0)
        #expect(task.sessions[0].changedFiles == ["Sources/WorkbenchApp/WorkbenchApp.swift"])
        #expect(task.sessions[0].logs.contains { $0.message == "Started" })
    }

    @Test @MainActor func cancellationUpdatesTaskAndActiveSession() async throws {
        let container = try TestStore.makeContainer()
        let context = container.mainContext
        let workspace = Workspace(name: "Workbench", repositoryPath: "/tmp/workbench")
        let task = WorkbenchTask(
            title: "Long task",
            prompt: "Keep running",
            agent: "Test Agent",
            status: .queued,
            workspace: workspace
        )
        context.insert(workspace)
        context.insert(task)

        let provider = SuspendedAgentProvider()
        let model = AppModel(agentProvider: provider)
        model.selectedWorkspace = workspace
        model.selectedTask = task
        model.runSelectedTask(context: context)
        #expect(task.status == .running)

        let taskID = task.id
        model.cancelSelectedTask(context: context)
        try await eventually { await provider.wasCancelled(taskID) }

        #expect(task.status == .cancelled)
        #expect(task.sessions.first?.status == .cancelled)
        #expect(task.sessions.first?.finishedAt != nil)
        #expect(task.sessions.first?.logs.contains { $0.level == .warning } == true)
    }
}

@Suite("Session orchestrator")
struct SessionOrchestratorTests {
    @Test @MainActor func preventsDuplicateRunsForTheSameTask() async throws {
        let container = try TestStore.makeContainer()
        let context = container.mainContext
        let workspace = Workspace(name: "Workbench", repositoryPath: "/tmp/workbench")
        let task = WorkbenchTask(
            title: "Long task",
            prompt: "Keep running",
            agent: "Test Agent",
            status: .queued,
            workspace: workspace
        )
        context.insert(workspace)
        context.insert(task)

        let provider = SuspendedAgentProvider()
        let orchestrator = SessionOrchestrator(agentProvider: provider)
        let firstSession = orchestrator.run(task: task, context: context)
        let duplicateSession = orchestrator.run(task: task, context: context)

        #expect(firstSession != nil)
        #expect(duplicateSession == nil)
        #expect(orchestrator.isRunning(taskID: task.id))
        #expect(task.sessions.count == 1)

        orchestrator.cancel(task: task, context: context)
        try await eventually { await provider.wasCancelled(task.id) }
        #expect(!orchestrator.isRunning(taskID: task.id))
    }
}

@Suite("Agent provider")
struct AgentProviderTests {
    @Test func previewProviderProducesACompleteExecution() async throws {
        let provider = PreviewAgentProvider()
        let snapshot = TaskSnapshot(
            id: UUID(),
            title: "Preview",
            prompt: "Run preview",
            repositoryPath: "/tmp/workbench"
        )
        let stream = await provider.execute(task: snapshot)
        var logCount = 0
        var changedFiles: [String] = []
        var exitCode: Int?

        for try await event in stream {
            switch event {
            case .log:
                logCount += 1
            case let .changedFile(path):
                changedFiles.append(path)
            case .requiresApproval:
                break
            case let .finished(code):
                exitCode = code
            }
        }

        #expect(logCount == 5)
        #expect(changedFiles.count == 2)
        #expect(exitCode == 0)
    }
}

private enum TestStore {
    @MainActor
    static func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Workspace.self,
            WorkbenchTask.self,
            AgentSession.self,
            LogEntry.self,
            configurations: configuration
        )
    }
}

private actor ImmediateAgentProvider: AgentProvider {
    let id = "immediate"
    let name = "Immediate"

    func execute(task: TaskSnapshot) async -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.log(.info, "Started"))
            continuation.yield(.changedFile("Sources/WorkbenchApp/WorkbenchApp.swift"))
            continuation.yield(.finished(exitCode: 0))
            continuation.finish()
        }
    }

    func cancel(taskID: UUID) async {}
}

private actor SuspendedAgentProvider: AgentProvider {
    let id = "suspended"
    let name = "Suspended"
    private var cancelledIDs: Set<UUID> = []

    func execute(task: TaskSnapshot) async -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { _ in }
    }

    func cancel(taskID: UUID) async {
        cancelledIDs.insert(taskID)
    }

    func wasCancelled(_ taskID: UUID) -> Bool {
        cancelledIDs.contains(taskID)
    }
}

@MainActor
private func eventually(
    timeout: Duration = .seconds(2),
    condition: @escaping @MainActor () async -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Condition was not satisfied within \(timeout)")
}
