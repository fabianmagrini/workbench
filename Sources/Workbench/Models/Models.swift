import Foundation
import SwiftData
import SwiftUI

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case draft = "Draft"
    case queued = "Queued"
    case running = "Running"
    case waitingApproval = "Waiting Approval"
    case failed = "Failed"
    case completed = "Completed"
    case cancelled = "Cancelled"

    var id: Self { self }

    var color: Color {
        switch self {
        case .draft, .queued: .secondary
        case .running: .green
        case .waitingApproval: .orange
        case .failed, .cancelled: .red
        case .completed: .blue
        }
    }
}

enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: Self { self }

    var color: Color {
        switch self {
        case .low: .secondary
        case .medium: .orange
        case .high: .red
        }
    }
}

enum LogLevel: String, Codable {
    case info
    case success
    case warning
    case error
}

@Model
final class Workspace {
    @Attribute(.unique) var id: UUID
    var name: String
    var repositoryPath: String
    var gitBranch: String
    var preferredAgent: String
    var isFavorite: Bool
    var isArchived: Bool
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WorkbenchTask.workspace)
    var tasks: [WorkbenchTask] = []

    init(
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
final class WorkbenchTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var taskDescription: String
    var prompt: String
    var agent: String
    var status: TaskStatus
    var priority: TaskPriority
    var labels: [String]
    var createdAt: Date
    var updatedAt: Date
    var workspace: Workspace?

    @Relationship(deleteRule: .cascade, inverse: \AgentSession.task)
    var sessions: [AgentSession] = []

    init(
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
final class AgentSession {
    @Attribute(.unique) var id: UUID
    var agent: String
    var startedAt: Date
    var finishedAt: Date?
    var exitCode: Int?
    var status: TaskStatus
    var changedFiles: [String]
    var task: WorkbenchTask?

    @Relationship(deleteRule: .cascade, inverse: \LogEntry.session)
    var logs: [LogEntry] = []

    init(
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
final class LogEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var level: LogLevel
    var message: String
    var session: AgentSession?

    init(
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
