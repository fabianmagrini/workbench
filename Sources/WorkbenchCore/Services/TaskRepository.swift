import SwiftData

public struct NewTaskInput: Sendable, Equatable {
    public let title: String
    public let prompt: String
    public let agent: String
    public let priority: TaskPriority

    public init(title: String, prompt: String, agent: String, priority: TaskPriority) {
        self.title = title
        self.prompt = prompt
        self.agent = agent
        self.priority = priority
    }
}

@MainActor
public final class TaskRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func create(_ input: NewTaskInput, in workspace: Workspace) throws -> WorkbenchTask {
        let task = WorkbenchTask(
            title: input.title,
            taskDescription: input.prompt,
            prompt: input.prompt,
            agent: input.agent,
            status: .queued,
            priority: input.priority,
            workspace: workspace
        )
        context.insert(task)
        workspace.updatedAt = .now
        try context.save()
        return task
    }
}

