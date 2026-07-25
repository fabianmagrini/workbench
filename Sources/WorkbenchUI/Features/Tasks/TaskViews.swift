import SwiftData
import SwiftUI
#if SWIFT_PACKAGE
import WorkbenchCore
#endif

struct TaskListView: View {
    @Bindable var model: AppModel
    @Query(sort: \WorkbenchTask.updatedAt, order: .reverse) private var allTasks: [WorkbenchTask]

    private var tasks: [WorkbenchTask] {
        allTasks.filter { task in
            let belongsToWorkspace = task.workspace?.id == model.selectedWorkspace?.id
            let matchesStatus = model.statusFilter == nil || task.status == model.statusFilter
            let matchesSearch = model.searchText.isEmpty
                || task.title.localizedStandardContains(model.searchText)
                || task.prompt.localizedStandardContains(model.searchText)
            return belongsToWorkspace && matchesStatus && matchesSearch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if tasks.isEmpty {
                ContentUnavailableView(
                    "No Tasks",
                    systemImage: "checklist",
                    description: Text("Create a task to start an agent session.")
                )
            } else {
                List(tasks, selection: $model.selectedTask) { task in
                    TaskRow(task: task)
                        .tag(task)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Tasks")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Tasks")
                        .font(.title2.weight(.semibold))
                    Text("Orchestrate and monitor work across your agents.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("\(runningCount) agents active", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(runningCount > 0 ? .green : .secondary)
            }

            Picker("Status", selection: $model.statusFilter) {
                Text("All").tag(TaskStatus?.none)
                ForEach(TaskStatus.allCases) { status in
                    Text(status.rawValue).tag(TaskStatus?.some(status))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding()
    }

    private var runningCount: Int {
        allTasks.filter { $0.workspace?.id == model.selectedWorkspace?.id && $0.status == .running }.count
    }
}

private struct TaskRow: View {
    let task: WorkbenchTask

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(task.priority.color)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .fontWeight(.medium)
                Text(task.prompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
            StatusBadge(status: task.status)

            Label(task.agent, systemImage: "cpu")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 105, alignment: .leading)

            Text(task.updatedAt, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }
}

struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var model: AppModel

    var body: some View {
        if let task = model.selectedTask {
            VStack(spacing: 0) {
                taskHeader(task)
                Divider()
                SessionConsoleView(task: task, searchText: $model.consoleSearchText)
            }
            .navigationTitle(task.title)
            .toolbar {
                ToolbarItemGroup {
                    if task.status == .running {
                        Button("Cancel", systemImage: "stop.fill") {
                            model.cancelSelectedTask(context: modelContext)
                        }
                    } else {
                        Button("Run", systemImage: "play.fill") {
                            model.runSelectedTask(context: modelContext)
                        }
                        .accessibilityIdentifier("task.detail.run")
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "Select a Task",
                systemImage: "cursorarrow.click",
                description: Text("Choose a task to inspect its prompt, sessions, and output.")
            )
        }
    }

    private func taskHeader(_ task: WorkbenchTask) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusBadge(status: task.status)
                Label(task.agent, systemImage: "cpu")
                Spacer()
                Text(task.updatedAt, format: .relative(presentation: .named))
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Text(task.taskDescription)
                .foregroundStyle(.secondary)

            GroupBox("Prompt") {
                Text(task.prompt)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.vertical, 4)
            }
        }
        .padding()
    }
}

struct StatusBadge: View {
    let status: TaskStatus

    var body: some View {
        Label(status.rawValue, systemImage: "circle.fill")
            .accessibilityIdentifier("task.status.\(status.rawValue)")
            .font(.caption2.weight(.medium))
            .foregroundStyle(status.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.12), in: Capsule())
    }
}

private struct SessionConsoleView: View {
    let task: WorkbenchTask
    @Binding var searchText: String
    @State private var selectedTab = "Console"

    private var session: AgentSession? {
        task.sessions.sorted { $0.startedAt > $1.startedAt }.first
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let session {
                    Label("Live execution", systemImage: session.status == .running ? "dot.radiowaves.left.and.right" : "terminal")
                        .foregroundStyle(session.status == .running ? .green : .secondary)
                    Text("· \(session.agent) · \(session.startedAt, format: .dateTime.hour().minute())")
                        .foregroundStyle(.secondary)
                } else {
                    Label("No session", systemImage: "terminal")
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Picker("View", selection: $selectedTab) {
                    Text("Console").tag("Console")
                    Text("Changes").tag("Changes")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            .font(.caption)
            .padding(10)
            Divider()

            if selectedTab == "Console" {
                ConsoleView(session: session, searchText: $searchText)
            } else {
                ChangedFilesView(files: session?.changedFiles ?? [])
            }
        }
    }
}

private struct ConsoleView: View {
    let session: AgentSession?
    @Binding var searchText: String

    private var logs: [LogEntry] {
        let entries = (session?.logs ?? []).sorted { $0.timestamp < $1.timestamp }
        guard !searchText.isEmpty else { return entries }
        return entries.filter { $0.message.localizedStandardContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search console", text: $searchText)
                    .textFieldStyle(.plain)
                Button("Clear", systemImage: "xmark.circle") {
                    searchText = ""
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .disabled(searchText.isEmpty)
            }
            .padding(8)
            .background(.bar)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(logs) { log in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(log.timestamp, format: .dateTime.hour().minute().second())
                                .foregroundStyle(.tertiary)
                            Text(log.message)
                                .foregroundStyle(logColor(log.level))
                                .textSelection(.enabled)
                        }
                    }
                }
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.35))
        }
    }

    private func logColor(_ level: LogLevel) -> Color {
        switch level {
        case .info: .primary
        case .success: .green
        case .warning: .orange
        case .error: .red
        }
    }
}

private struct ChangedFilesView: View {
    let files: [String]

    var body: some View {
        if files.isEmpty {
            ContentUnavailableView("No Changes", systemImage: "doc.badge.ellipsis")
        } else {
            List(files, id: \.self) { path in
                Label(path, systemImage: "doc.text")
                    .font(.system(.callout, design: .monospaced))
            }
            .listStyle(.inset)
        }
    }
}

struct NewTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var model: AppModel

    @State private var title = ""
    @State private var prompt = ""
    @State private var agent = "Codex"
    @State private var priority: TaskPriority = .medium

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title, prompt: Text("Implement JWT refresh flow"))
                    .accessibilityIdentifier("task.new.title")

                Picker("Agent", selection: $agent) {
                    ForEach(["Codex", "Claude Code", "Amp", "Gemini CLI"], id: \.self) {
                        Text($0)
                    }
                }

                Picker("Priority", selection: $priority) {
                    ForEach(TaskPriority.allCases) { priority in
                        Text(priority.rawValue).tag(priority)
                    }
                }

                TextEditor(text: $prompt)
                    .accessibilityIdentifier("task.new.prompt")
                    .font(.body.monospaced())
                    .frame(minHeight: 180)
                    .overlay(alignment: .topLeading) {
                        if prompt.isEmpty {
                            Text("Describe the work you want the agent to perform…")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .formStyle(.grouped)
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        model.createTask(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                            agent: agent,
                            priority: priority,
                            context: modelContext
                        )
                        dismiss()
                    }
                    .accessibilityIdentifier("task.new.create")
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || prompt.isEmpty)
                }
            }
        }
        .frame(width: 560, height: 430)
    }
}
