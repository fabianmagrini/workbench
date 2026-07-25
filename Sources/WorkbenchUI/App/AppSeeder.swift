import Foundation
import SwiftData
#if SWIFT_PACKAGE
import WorkbenchCore
#endif

@MainActor
public final class AppSeeder {
    private let context: ModelContext
    private let repositoryPath: String

    public init(
        context: ModelContext,
        repositoryPath: String = FileManager.default.currentDirectoryPath
    ) {
        self.context = context
        self.repositoryPath = repositoryPath
    }

    public func seedIfNeeded(workspaces: [Workspace]) -> Workspace? {
        guard workspaces.isEmpty else {
            return workspaces.first
        }

        let workspace = Workspace(
            name: "Workbench",
            repositoryPath: repositoryPath,
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
                "Sources/WorkbenchApp/WorkbenchApp.swift",
                "Sources/WorkbenchUI/Features/Tasks/TaskViews.swift",
                "Sources/WorkbenchCore/Models/Models.swift"
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

        try? context.save()
        return workspace
    }
}
