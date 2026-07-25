import SwiftUI
#if SWIFT_PACKAGE
import WorkbenchCore
#endif

struct RepositoryBrowserView: View {
    let workspace: Workspace?
    @Bindable var viewModel: RepositoryBrowserViewModel

    var body: some View {
        Group {
            if let workspace {
                HSplitView {
                    List(viewModel.entries, selection: $viewModel.selectedEntry) { entry in
                        Label(entry.name, systemImage: entry.isDirectory ? "folder" : "doc")
                            .tag(entry)
                    }
                    .frame(minWidth: 240)

                    if let selectedEntry = viewModel.selectedEntry {
                        FilePreview(
                            entry: selectedEntry,
                            contents: viewModel.previewContents
                        )
                    } else {
                        ContentUnavailableView("Select a File", systemImage: "doc.text.magnifyingglass")
                    }
                }
                .task(id: workspace.repositoryPath) {
                    await viewModel.load(repositoryPath: workspace.repositoryPath)
                }
                .task(id: viewModel.selectedEntry) {
                    await viewModel.loadPreview()
                }
                .toolbar {
                    ToolbarItemGroup {
                        Button("Reveal in Finder", systemImage: "finder") {
                            viewModel.reveal(repositoryPath: workspace.repositoryPath)
                        }
                        Button("Open in Terminal", systemImage: "terminal") {
                            viewModel.openInTerminal(repositoryPath: workspace.repositoryPath)
                        }
                    }
                }
            } else {
                ContentUnavailableView("No Workspace", systemImage: "folder.badge.questionmark")
            }
        }
        .navigationTitle("Files")
        .alert(
            "Unable to Read Repository",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

private struct FilePreview: View {
    let entry: RepositoryEntry
    let contents: String

    var body: some View {
        if entry.isDirectory {
            ContentUnavailableView(entry.name, systemImage: "folder")
        } else {
            ScrollView([.horizontal, .vertical]) {
                Text(contents)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding()
            }
        }
    }
}
