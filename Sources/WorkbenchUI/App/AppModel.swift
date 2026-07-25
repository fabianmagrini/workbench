import Foundation
import Observation
import SwiftData
#if SWIFT_PACKAGE
import WorkbenchAgents
import WorkbenchCore
#endif

@MainActor
@Observable
final class AppModel {
    enum SidebarSelection: String, CaseIterable, Identifiable {
        case tasks = "Tasks"
        case sessions = "Sessions"
        case files = "Files"
        case history = "History"

        var id: Self { self }

        var systemImage: String {
            switch self {
            case .tasks: "checklist"
            case .sessions: "bolt.horizontal.circle"
            case .files: "folder"
            case .history: "clock.arrow.circlepath"
            }
        }
    }

    var sidebarSelection: SidebarSelection = .tasks
    var selectedWorkspace: Workspace?
    var selectedTask: WorkbenchTask?
    var searchText = ""
    var statusFilter: TaskStatus?
    var showsNewTask = false
    var showsInspector = true
    var consoleSearchText = ""

    private let sessionOrchestrator: SessionOrchestrator

    init(agentProvider: any AgentProvider = CodexCLIProvider()) {
        sessionOrchestrator = SessionOrchestrator(agentProvider: agentProvider)
    }

    func seedIfNeeded(context: ModelContext, workspaces: [Workspace]) {
        guard workspaces.isEmpty else {
            if selectedWorkspace == nil {
                selectedWorkspace = workspaces.first
            }
            return
        }

        let workspace = Workspace(
            name: "Workbench",
            repositoryPath: FileManager.default.currentDirectoryPath,
            gitBranch: "main",
            preferredAgent: "Codex",
            isFavorite: true,
            tags: ["macOS", "SwiftUI"]
        )

        let tasks = [
            WorkbenchTask(
                title: "Build task console",
                taskDescription: "Implement the three-pane shell and live execution view.",
                prompt: "Build the Workbench task console described in the product specification.",
                agent: "Codex",
                status: .running,
                priority: .high,
                labels: ["UI", "MVP"],
                workspace: workspace
            ),
            WorkbenchTask(
                title: "Review persistence layer",
                taskDescription: "Audit SwiftData models and migration strategy.",
                prompt: "Review the persistence layer and report any migration risks.",
                agent: "Claude Code",
                status: .waitingApproval,
                priority: .high,
                labels: ["Data"],
                workspace: workspace
            ),
            WorkbenchTask(
                title: "Add command palette",
                taskDescription: "Create keyboard-first navigation for common actions.",
                prompt: "Add a native command palette to Workbench.",
                agent: "Amp",
                status: .queued,
                priority: .medium,
                labels: ["UX"],
                workspace: workspace
            ),
            WorkbenchTask(
                title: "Polish empty states",
                taskDescription: "Improve first-run guidance throughout the app.",
                prompt: "Polish the empty states in Workbench.",
                agent: "Codex",
                status: .completed,
                priority: .low,
                labels: ["UI"],
                workspace: workspace
            )
        ]

        context.insert(workspace)
        tasks.forEach(context.insert)

        let session = AgentSession(
            agent: "Codex",
            status: .running,
            changedFiles: [
                "Sources/Workbench/App/WorkbenchApp.swift",
                "Sources/Workbench/Features/Tasks/TaskDetailView.swift",
                "Sources/Workbench/Models/Models.swift"
            ],
            task: tasks[0]
        )
        context.insert(session)

        [
            LogEntry(level: .info, message: "Session started · codex-1", session: session),
            LogEntry(level: .info, message: "Reading docs/initial-spec.md", session: session),
            LogEntry(level: .success, message: "Mapped requirements to native architecture", session: session),
            LogEntry(level: .success, message: "NavigationSplitView implemented", session: session)
        ].forEach(context.insert)

        selectedWorkspace = workspace
        selectedTask = tasks[0]
        try? context.save()
    }

    func createTask(
        title: String,
        prompt: String,
        agent: String,
        priority: TaskPriority,
        context: ModelContext
    ) {
        guard let workspace = selectedWorkspace else { return }
        let task = WorkbenchTask(
            title: title,
            taskDescription: prompt,
            prompt: prompt,
            agent: agent,
            status: .queued,
            priority: priority,
            workspace: workspace
        )
        context.insert(task)
        workspace.updatedAt = .now
        selectedTask = task
        try? context.save()
    }

    func runSelectedTask(context: ModelContext) {
        guard let selectedTask else { return }
        sessionOrchestrator.run(task: selectedTask, context: context)
    }

    func cancelSelectedTask(context: ModelContext) {
        guard let selectedTask else { return }
        sessionOrchestrator.cancel(task: selectedTask, context: context)
    }
}
