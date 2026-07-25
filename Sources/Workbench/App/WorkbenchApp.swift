import SwiftData
import SwiftUI

@main
struct WorkbenchApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: Workspace.self,
                WorkbenchTask.self,
                AgentSession.self,
                LogEntry.self
            )
        } catch {
            fatalError("Unable to initialize Workbench data: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            WorkbenchRootView()
        }
        .modelContainer(modelContainer)
        .commands {
            WorkbenchCommands()
        }

        Settings {
            SettingsView()
        }
        .modelContainer(modelContainer)
    }
}

private struct WorkbenchCommands: Commands {
    @FocusedValue(\.newTaskAction) private var newTask
    @FocusedValue(\.runTaskAction) private var runTask
    @FocusedValue(\.cancelTaskAction) private var cancelTask

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Task") { newTask?() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(newTask == nil)
        }

        CommandMenu("Agent") {
            Button("Run Task") { runTask?() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(runTask == nil)

            Button("Cancel Task") { cancelTask?() }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(cancelTask == nil)
        }
    }
}

private struct NewTaskActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct RunTaskActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct CancelTaskActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var newTaskAction: (() -> Void)? {
        get { self[NewTaskActionKey.self] }
        set { self[NewTaskActionKey.self] = newValue }
    }

    var runTaskAction: (() -> Void)? {
        get { self[RunTaskActionKey.self] }
        set { self[RunTaskActionKey.self] = newValue }
    }

    var cancelTaskAction: (() -> Void)? {
        get { self[CancelTaskActionKey.self] }
        set { self[CancelTaskActionKey.self] = newValue }
    }
}
