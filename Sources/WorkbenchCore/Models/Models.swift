import Foundation
import SwiftData

public enum TaskStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case draft = "Draft"
    case queued = "Queued"
    case running = "Running"
    case waitingApproval = "Waiting Approval"
    case failed = "Failed"
    case completed = "Completed"
    case cancelled = "Cancelled"

    public var id: Self { self }
}

public enum TaskPriority: String, Codable, CaseIterable, Identifiable, Sendable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    public var id: Self { self }
}

public enum LogLevel: String, Codable, Sendable {
    case info
    case success
    case warning
    case error
}

@Model
public final class Workspace {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var repositoryPath: String
    public var gitBranch: String
    public var preferredAgent: String
    public var isFavorite: Bool
    public var isArchived: Bool
    public var tags: [String]
    public var createdAt: Date
    public var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WorkbenchTask.workspace)
    public var tasks: [WorkbenchTask] = []

    public init(
        id: UUID = UUID(),
        name: String,
        repositoryPath: String,
        gitBranch: String = "main",
        preferredAgent: String = "Codex",
        isFavorite: Bool = false,
        isArchived: Bool = false,
        tags: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.repositoryPath = repositoryPath
        self.gitBranch = gitBranch
        self.preferredAgent = preferredAgent
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class WorkbenchTask {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var taskDescription: String
    public var prompt: String
    public var agent: String
    public var status: TaskStatus
    public var priority: TaskPriority
    public var labels: [String]
    public var createdAt: Date
    public var updatedAt: Date
    public var workspace: Workspace?

    @Relationship(deleteRule: .cascade, inverse: \AgentSession.task)
    public var sessions: [AgentSession] = []

    public init(
        id: UUID = UUID(),
        title: String,
        taskDescription: String = "",
        prompt: String,
        agent: String,
        status: TaskStatus = .draft,
        priority: TaskPriority = .medium,
        labels: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        workspace: Workspace? = nil
    ) {
        self.id = id
        self.title = title
        self.taskDescription = taskDescription
        self.prompt = prompt
        self.agent = agent
        self.status = status
        self.priority = priority
        self.labels = labels
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.workspace = workspace
    }
}

@Model
public final class AgentSession {
    @Attribute(.unique) public var id: UUID
    public var agent: String
    public var startedAt: Date
    public var finishedAt: Date?
    public var exitCode: Int?
    public var status: TaskStatus
    public var changedFiles: [String]
    public var task: WorkbenchTask?

    @Relationship(deleteRule: .cascade, inverse: \LogEntry.session)
    public var logs: [LogEntry] = []

    public init(
        id: UUID = UUID(),
        agent: String,
        startedAt: Date = .now,
        finishedAt: Date? = nil,
        exitCode: Int? = nil,
        status: TaskStatus = .running,
        changedFiles: [String] = [],
        task: WorkbenchTask? = nil
    ) {
        self.id = id
        self.agent = agent
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.exitCode = exitCode
        self.status = status
        self.changedFiles = changedFiles
        self.task = task
    }
}

@Model
public final class LogEntry {
    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    public var level: LogLevel
    public var message: String
    public var session: AgentSession?

    public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        level: LogLevel = .info,
        message: String,
        session: AgentSession? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.session = session
    }
}
