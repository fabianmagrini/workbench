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

@Suite("Application view model")
struct AppViewModelTests {
    @Test @MainActor func seedIsIdempotent() throws {
        let container = try TestStore.makeContainer()
        let context = container.mainContext
        let model = makeAppViewModel(context: context)

        model.seedIfNeeded(workspaces: [])
        let firstWorkspaces = try context.fetch(FetchDescriptor<Workspace>())
        model.seedIfNeeded(workspaces: firstWorkspaces)

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

        let model = makeAppViewModel(context: context)
        model.selectedWorkspace = workspace
        model.createTask(
            NewTaskInput(
                title: "Add approvals",
                prompt: "Implement the approval workflow",
                agent: "Codex",
                priority: .high
            )
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

        let model = makeAppViewModel(context: context)
        model.selectedWorkspace = workspace
        model.selectedTask = task
        model.runSelectedTask()

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
        let model = makeAppViewModel(context: context, provider: provider)
        model.selectedWorkspace = workspace
        model.selectedTask = task
        model.runSelectedTask()
        #expect(task.status == .running)

        let taskID = task.id
        model.cancelSelectedTask()
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
        let orchestrator = SessionOrchestrator(agentProvider: provider, context: context)
        let firstSession = orchestrator.run(task: task)
        let duplicateSession = orchestrator.run(task: task)

        #expect(firstSession != nil)
        #expect(duplicateSession == nil)
        #expect(orchestrator.isRunning(taskID: task.id))
        #expect(task.sessions.count == 1)

        orchestrator.cancel(task: task)
        try await eventually { await provider.wasCancelled(task.id) }
        #expect(!orchestrator.isRunning(taskID: task.id))
    }
}

@Suite("Feature view models")
struct FeatureViewModelTests {
    @Test @MainActor func newTaskValidationNormalizesInput() {
        let viewModel = NewTaskViewModel()
        #expect(!viewModel.canCreate)

        viewModel.title = "  Add approvals  "
        viewModel.prompt = "\nImplement approval handling. \n"
        viewModel.priority = .high

        #expect(viewModel.canCreate)
        #expect(viewModel.input.title == "Add approvals")
        #expect(viewModel.input.prompt == "Implement approval handling.")
        #expect(viewModel.input.priority == .high)
    }

    @Test @MainActor func repositoryBrowserLoadsEntriesAndPreview() async {
        let fileURL = URL(fileURLWithPath: "/tmp/workbench/README.md")
        let directoryURL = URL(fileURLWithPath: "/tmp/workbench/Sources")
        let service = StubRepositoryFileService(
            entries: [
                RepositoryEntry(url: directoryURL, isDirectory: true),
                RepositoryEntry(url: fileURL, isDirectory: false)
            ],
            contents: "# Workbench"
        )
        let viewModel = RepositoryBrowserViewModel(fileService: service)

        await viewModel.load(repositoryPath: "/tmp/workbench")
        viewModel.selectedEntry = viewModel.entries.last
        await viewModel.loadPreview()

        #expect(viewModel.entries.count == 2)
        #expect(viewModel.previewContents == "# Workbench")
        #expect(viewModel.errorMessage == nil)
    }

    @Test @MainActor func repositoryBrowserSurfacesLoadingFailure() async {
        let viewModel = RepositoryBrowserViewModel(
            fileService: StubRepositoryFileService(error: TestError.expected)
        )

        await viewModel.load(repositoryPath: "/missing")

        #expect(viewModel.entries.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(!viewModel.isLoading)
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

    @Test func codexProviderBuildsCommandAndTranslatesJSONLEvents() async throws {
        let output = """
        {"type":"thread.started","thread_id":"thread-1"}
        {"type":"item.completed","item":{"type":"reasoning","text":"Inspecting files"}}
        {"type":"item.completed","item":{"type":"command_execution","command":"swift test","aggregated_output":"Passed","exit_code":0}}
        {"type":"item.completed","item":{"type":"file_change","changes":[{"path":"Sources/App.swift","kind":"update"}]}}
        {"type":"item.completed","item":{"type":"agent_message","text":"Implemented the change"}}
        """
        let runner = RecordingProcessRunner(
            result: ProcessResult(
                standardOutput: Data(output.utf8),
                standardError: Data(),
                exitCode: 0,
                terminationReason: .exit
            )
        )
        let executableURL = URL(fileURLWithPath: "/test/bin/codex")
        let provider = CodexCLIProvider(
            executableURL: executableURL,
            processRunner: runner
        )
        let snapshot = TaskSnapshot(
            id: UUID(),
            title: "Implement",
            prompt: "Make the change",
            repositoryPath: "/tmp/workbench"
        )

        let events = try await collect(await provider.execute(task: snapshot))
        let request = await runner.lastRequest

        #expect(request?.executableURL == executableURL)
        #expect(request?.currentDirectoryURL?.path == "/tmp/workbench")
        #expect(request?.arguments == [
            "exec",
            "--json",
            "--color", "never",
            "--sandbox", "workspace-write",
            "--cd", "/tmp/workbench",
            "Make the change"
        ])
        #expect(events.containsLog(level: .info, message: "Codex session started"))
        #expect(events.containsLog(level: .info, message: "Inspecting files"))
        #expect(events.containsLog(level: .info, message: "$ swift test"))
        #expect(events.containsLog(level: .success, message: "Implemented the change"))
        #expect(events.containsChangedFile("Sources/App.swift"))
        #expect(events.containsFinished(exitCode: 0))
    }

    @Test func codexProviderSurfacesStandardErrorAndExitCode() async throws {
        let runner = RecordingProcessRunner(
            result: ProcessResult(
                standardOutput: Data(),
                standardError: Data("Authentication required\n".utf8),
                exitCode: 9,
                terminationReason: .exit
            )
        )
        let provider = CodexCLIProvider(
            executableURL: URL(fileURLWithPath: "/test/bin/codex"),
            processRunner: runner
        )
        let events = try await collect(
            await provider.execute(
                task: TaskSnapshot(
                    id: UUID(),
                    title: "Fail",
                    prompt: "Run",
                    repositoryPath: "/tmp/workbench"
                )
            )
        )

        #expect(events.containsLog(level: .error, message: "Authentication required"))
        #expect(events.containsFinished(exitCode: 9))
    }

    @Test func codexProviderPropagatesCancellationToProcessRunner() async throws {
        let runner = SuspendedProcessRunner()
        let provider = CodexCLIProvider(
            executableURL: URL(fileURLWithPath: "/test/bin/codex"),
            processRunner: runner
        )
        let taskID = UUID()
        let stream = await provider.execute(
            task: TaskSnapshot(
                id: taskID,
                title: "Cancel",
                prompt: "Wait",
                repositoryPath: "/tmp/workbench"
            )
        )
        let consumer = Task {
            for try await _ in stream {}
        }

        try await eventually { await runner.didStart }
        await provider.cancel(taskID: taskID)
        try await eventually { await runner.wasCancelled }
        _ = try await consumer.value
    }
}

@Suite("Process runner")
struct ProcessRunnerTests {
    @Test func capturesStandardOutputAndStandardErrorSeparately() async throws {
        let runner = LocalProcessRunner()
        let result = try await runner.run(
            ProcessRequest(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "printf output; printf error >&2; exit 7"]
            )
        )

        #expect(result.standardOutputString == "output")
        #expect(result.standardErrorString == "error")
        #expect(result.exitCode == 7)
        #expect(result.terminationReason == .exit)
    }

    @Test func appliesWorkingDirectoryAndEnvironment() async throws {
        let runner = LocalProcessRunner()
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let result = try await runner.run(
            ProcessRequest(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "printf '%s|%s' \"$PWD\" \"$WORKBENCH_TEST_VALUE\""],
                currentDirectoryURL: temporaryDirectory,
                environment: ["WORKBENCH_TEST_VALUE": "configured"]
            )
        )

        #expect(
            result.standardOutputString.hasSuffix(
                "/\(temporaryDirectory.lastPathComponent)|configured"
            )
        )
        #expect(result.exitCode == 0)
    }

    @Test func cancellationTerminatesTheChildProcess() async throws {
        let runner = LocalProcessRunner()
        let execution = Task {
            try await runner.run(
                ProcessRequest(
                    executableURL: URL(fileURLWithPath: "/bin/sleep"),
                    arguments: ["30"]
                )
            )
        }

        try await Task.sleep(for: .milliseconds(50))
        execution.cancel()
        let result = try await execution.value

        #expect(result.terminationReason == .uncaughtSignal)
        #expect(result.exitCode != 0)
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

@MainActor
private func makeAppViewModel(
    context: ModelContext,
    provider: any AgentProvider = ImmediateAgentProvider()
) -> AppViewModel {
    AppViewModel(
        seeder: AppSeeder(context: context, repositoryPath: "/tmp/workbench"),
        taskRepository: TaskRepository(context: context),
        sessionOrchestrator: SessionOrchestrator(
            agentProvider: provider,
            context: context
        )
    )
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

private actor RecordingProcessRunner: ProcessRunner {
    private(set) var lastRequest: ProcessRequest?
    let result: ProcessResult

    init(result: ProcessResult) {
        self.result = result
    }

    func run(_ request: ProcessRequest) async throws -> ProcessResult {
        lastRequest = request
        return result
    }
}

private actor SuspendedProcessRunner: ProcessRunner {
    private(set) var didStart = false
    private(set) var wasCancelled = false

    func run(_ request: ProcessRequest) async throws -> ProcessResult {
        didStart = true
        return try await withTaskCancellationHandler {
            try await Task.sleep(for: .seconds(30))
            return ProcessResult(
                standardOutput: Data(),
                standardError: Data(),
                exitCode: 0,
                terminationReason: .exit
            )
        } onCancel: {
            Task { await self.recordCancellation() }
        }
    }

    private func recordCancellation() {
        wasCancelled = true
    }
}

private enum TestError: Error {
    case expected
}

private actor StubRepositoryFileService: RepositoryFileServing {
    let entriesResult: Result<[RepositoryEntry], Error>
    let contentsResult: Result<String, Error>

    init(
        entries: [RepositoryEntry] = [],
        contents: String = "",
        error: Error? = nil
    ) {
        if let error {
            entriesResult = .failure(error)
            contentsResult = .failure(error)
        } else {
            entriesResult = .success(entries)
            contentsResult = .success(contents)
        }
    }

    func entries(at repositoryURL: URL) async throws -> [RepositoryEntry] {
        try entriesResult.get()
    }

    func contents(of entry: RepositoryEntry) async throws -> String {
        try contentsResult.get()
    }
}

private func collect(
    _ stream: AsyncThrowingStream<AgentEvent, Error>
) async throws -> [AgentEvent] {
    var events: [AgentEvent] = []
    for try await event in stream {
        events.append(event)
    }
    return events
}

private extension Array where Element == AgentEvent {
    func containsLog(level: LogLevel, message: String) -> Bool {
        contains {
            if case let .log(eventLevel, eventMessage) = $0 {
                return eventLevel == level && eventMessage == message
            }
            return false
        }
    }

    func containsChangedFile(_ path: String) -> Bool {
        contains {
            if case let .changedFile(eventPath) = $0 {
                return eventPath == path
            }
            return false
        }
    }

    func containsFinished(exitCode: Int) -> Bool {
        contains {
            if case let .finished(eventExitCode) = $0 {
                return eventExitCode == exitCode
            }
            return false
        }
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
