import SwiftUI

public struct WorkbenchCommands: Commands {
    @FocusedValue(\.newTaskAction) private var newTask
    @FocusedValue(\.runTaskAction) private var runTask
    @FocusedValue(\.cancelTaskAction) private var cancelTask

    public init() {}

    public var body: some Commands {
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

public struct NewTaskActionKey: FocusedValueKey {
    public typealias Value = () -> Void
}

public struct RunTaskActionKey: FocusedValueKey {
    public typealias Value = () -> Void
}

public struct CancelTaskActionKey: FocusedValueKey {
    public typealias Value = () -> Void
}

public extension FocusedValues {
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
