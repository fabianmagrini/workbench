import AppKit
import SwiftUI
#if SWIFT_PACKAGE
import WorkbenchCore
#endif

struct RepositoryBrowserView: View {
    let workspace: Workspace?
    @State private var entries: [RepositoryEntry] = []
    @State private var selectedEntry: RepositoryEntry?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let workspace {
                HSplitView {
                    List(entries, selection: $selectedEntry) { entry in
                        Label(entry.name, systemImage: entry.isDirectory ? "folder" : "doc")
                            .tag(entry)
                    }
                    .frame(minWidth: 240)

                    if let selectedEntry {
                        FilePreview(entry: selectedEntry)
                    } else {
                        ContentUnavailableView("Select a File", systemImage: "doc.text.magnifyingglass")
                    }
                }
                .task(id: workspace.repositoryPath) { loadEntries(at: workspace.repositoryPath) }
                .toolbar {
                    ToolbarItemGroup {
                        Button("Reveal in Finder", systemImage: "finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([
                                URL(fileURLWithPath: workspace.repositoryPath)
                            ])
                        }
                        Button("Open in Terminal", systemImage: "terminal") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: workspace.repositoryPath))
                        }
                    }
                }
            } else {
                ContentUnavailableView("No Workspace", systemImage: "folder.badge.questionmark")
            }
        }
        .navigationTitle("Files")
        .alert("Unable to Read Repository", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadEntries(at path: String) {
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            entries = try urls.map { url in
                let values = try url.resourceValues(forKeys: [.isDirectoryKey])
                return RepositoryEntry(url: url, isDirectory: values.isDirectory ?? false)
            }
            .sorted {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct RepositoryEntry: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    var id: URL { url }
    var name: String { url.lastPathComponent }
}

private struct FilePreview: View {
    let entry: RepositoryEntry
    @State private var contents = ""

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
            .task(id: entry.id) {
                contents = (try? String(contentsOf: entry.url, encoding: .utf8))
                    ?? "Preview unavailable for this file."
            }
        }
    }
}
