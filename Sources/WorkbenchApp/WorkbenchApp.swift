import SwiftData
import SwiftUI
#if SWIFT_PACKAGE
import WorkbenchCore
import WorkbenchUI
#endif

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
