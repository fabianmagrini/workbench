import SwiftData
import SwiftUI
#if SWIFT_PACKAGE
import WorkbenchAgents
import WorkbenchCore
import WorkbenchUI
#endif

@main
struct WorkbenchApp: App {
    private let modelContainer: ModelContainer
    private let viewModel: AppViewModel

    init() {
        do {
            let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
            let configuration = ModelConfiguration(isStoredInMemoryOnly: isUITesting)
            let container = try ModelContainer(
                for: Workspace.self,
                WorkbenchTask.self,
                AgentSession.self,
                LogEntry.self,
                configurations: configuration
            )
            let context = container.mainContext
            let provider: any AgentProvider = isUITesting
                ? PreviewAgentProvider()
                : CodexCLIProvider()

            modelContainer = container
            viewModel = AppViewModel(
                seeder: AppSeeder(context: context),
                taskRepository: TaskRepository(context: context),
                sessionOrchestrator: SessionOrchestrator(
                    agentProvider: provider,
                    context: context
                )
            )
        } catch {
            fatalError("Unable to initialize Workbench data: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            WorkbenchRootView(viewModel: viewModel)
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
