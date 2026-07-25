import Observation
#if SWIFT_PACKAGE
import WorkbenchAgents
import WorkbenchCore
#endif

@MainActor
@Observable
public final class AppViewModel {
    public enum SidebarSelection: String, CaseIterable, Identifiable {
        case tasks = "Tasks"
        case sessions = "Sessions"
        case files = "Files"
        case history = "History"

        public var id: Self { self }

        public var systemImage: String {
            switch self {
            case .tasks: "checklist"
            case .sessions: "bolt.horizontal.circle"
            case .files: "folder"
            case .history: "clock.arrow.circlepath"
            }
        }
    }

    var sidebarSelection: SidebarSelection = .tasks
    var selectedWorkspace: Workspace?
    var selectedTask: WorkbenchTask?
    var searchText = ""
    var statusFilter: TaskStatus?
    var showsNewTask = false
    var showsInspector = true
    var consoleSearchText = ""

    private let seeder: AppSeeder
    private let taskRepository: TaskRepository
    private let sessionOrchestrator: SessionOrchestrator
    let repositoryBrowserViewModel: RepositoryBrowserViewModel

    public init(
        seeder: AppSeeder,
        taskRepository: TaskRepository,
        sessionOrchestrator: SessionOrchestrator,
        repositoryFileService: any RepositoryFileServing = RepositoryFileService()
    ) {
        self.seeder = seeder
        self.taskRepository = taskRepository
        self.sessionOrchestrator = sessionOrchestrator
        repositoryBrowserViewModel = RepositoryBrowserViewModel(
            fileService: repositoryFileService
        )
    }

    func seedIfNeeded(workspaces: [Workspace]) {
        guard selectedWorkspace == nil else { return }
        selectedWorkspace = seeder.seedIfNeeded(workspaces: workspaces)
        selectedTask = selectedWorkspace?.tasks.first { $0.title == "Build task console" }
    }

    func createTask(_ input: NewTaskInput) {
        guard let workspace = selectedWorkspace else { return }
        selectedTask = try? taskRepository.create(input, in: workspace)
    }

    func runSelectedTask() {
        guard let selectedTask else { return }
        sessionOrchestrator.run(task: selectedTask)
    }

    func cancelSelectedTask() {
        guard let selectedTask else { return }
        sessionOrchestrator.cancel(task: selectedTask)
    }
}
