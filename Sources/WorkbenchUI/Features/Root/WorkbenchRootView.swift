import SwiftData
import SwiftUI
#if SWIFT_PACKAGE
import WorkbenchCore
#endif

public struct WorkbenchRootView: View {
    @Query(sort: \Workspace.updatedAt, order: .reverse) private var workspaces: [Workspace]
    @State private var model: AppViewModel

    public init(viewModel: AppViewModel) {
        _model = State(initialValue: viewModel)
    }

    public var body: some View {
        HStack(spacing: 0) {
            NavigationSplitView {
                SidebarView(model: model, workspaces: workspaces)
                    .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
            } content: {
                ContentView(model: model)
                    .navigationSplitViewColumnWidth(min: 420, ideal: 560)
            } detail: {
                TaskDetailView(model: model)
                    .navigationSplitViewColumnWidth(min: 360, ideal: 460)
            }
            .navigationSplitViewStyle(.balanced)

            if model.showsInspector {
                Divider()
                InspectorView(task: model.selectedTask)
                    .frame(width: 300)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: model.showsInspector)
        .frame(minWidth: 1_050, minHeight: 680)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    model.showsInspector.toggle()
                } label: {
                    Label("Toggle Inspector", systemImage: "sidebar.trailing")
                }

                Button {
                    model.runSelectedTask()
                } label: {
                    Label("Run", systemImage: "play.fill")
                }
                .accessibilityIdentifier("task.run")
                .disabled(model.selectedTask?.status == .running)

                Button {
                    model.showsNewTask = true
                } label: {
                    Label("New Task", systemImage: "plus")
                }
                .accessibilityIdentifier("task.new")
                .buttonStyle(.borderedProminent)
            }
        }
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search tasks")
        .sheet(isPresented: $model.showsNewTask) {
            NewTaskView(model: model)
        }
        .focusedSceneValue(\.newTaskAction) {
            model.showsNewTask = true
        }
        .focusedSceneValue(\.runTaskAction) {
            model.runSelectedTask()
        }
        .focusedSceneValue(\.cancelTaskAction) {
            model.cancelSelectedTask()
        }
        .task {
            model.seedIfNeeded(workspaces: workspaces)
        }
        .accessibilityIdentifier("workbench.root")
    }
}

private struct SidebarView: View {
    @Bindable var model: AppViewModel
    let workspaces: [Workspace]

    var body: some View {
        List(selection: $model.sidebarSelection) {
            Section {
                ForEach(AppViewModel.SidebarSelection.allCases) { item in
                    Label(item.rawValue, systemImage: item.systemImage)
                        .tag(item)
                }
            }

            Section("Workspaces") {
                ForEach(workspaces) { workspace in
                    Button {
                        model.selectedWorkspace = workspace
                        model.selectedTask = nil
                    } label: {
                        WorkspaceRow(workspace: workspace)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        model.selectedWorkspace?.id == workspace.id
                            ? Color.accentColor.opacity(0.15)
                            : Color.clear
                    )
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            if let workspace = model.selectedWorkspace {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                    Text(workspace.gitBranch)
                    Spacer()
                    Text("Clean")
                        .foregroundStyle(.green)
                }
                .font(.caption)
                .padding(10)
                .background(.bar)
            }
        }
        .navigationTitle("Workbench")
    }
}

private struct WorkspaceRow: View {
    let workspace: Workspace

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "shippingbox.fill")
                .frame(width: 28, height: 28)
                .foregroundStyle(.white)
                .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(workspace.name)
                        .fontWeight(.medium)
                    if workspace.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                Text(workspace.repositoryPath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct ContentView: View {
    @Bindable var model: AppViewModel

    var body: some View {
        Group {
            switch model.sidebarSelection {
            case .tasks:
                TaskListView(model: model)
            case .sessions:
                SessionsView(model: model)
            case .files:
                RepositoryBrowserView(
                    workspace: model.selectedWorkspace,
                    viewModel: model.repositoryBrowserViewModel
                )
            case .history:
                HistoryView(model: model)
            }
        }
    }
}
