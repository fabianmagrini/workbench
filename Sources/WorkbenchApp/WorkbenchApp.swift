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
            let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
            let configuration = ModelConfiguration(isStoredInMemoryOnly: isUITesting)
            modelContainer = try ModelContainer(
                for: Workspace.self,
                WorkbenchTask.self,
                AgentSession.self,
                LogEntry.self,
                configurations: configuration
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
