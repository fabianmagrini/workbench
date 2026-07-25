import AppKit
import Observation
#if SWIFT_PACKAGE
import WorkbenchCore
#endif

@MainActor
@Observable
final class RepositoryBrowserViewModel {
    var entries: [RepositoryEntry] = []
    var selectedEntry: RepositoryEntry?
    var previewContents = ""
    var errorMessage: String?
    var isLoading = false

    private let fileService: any RepositoryFileServing

    init(fileService: any RepositoryFileServing = RepositoryFileService()) {
        self.fileService = fileService
    }

    func load(repositoryPath: String) async {
        isLoading = true
        errorMessage = nil
        selectedEntry = nil
        previewContents = ""
        defer { isLoading = false }

        do {
            entries = try await fileService.entries(
                at: URL(fileURLWithPath: repositoryPath)
            )
        } catch {
            entries = []
            errorMessage = error.localizedDescription
        }
    }

    func loadPreview() async {
        guard let selectedEntry, !selectedEntry.isDirectory else {
            previewContents = ""
            return
        }
        do {
            previewContents = try await fileService.contents(of: selectedEntry)
        } catch {
            previewContents = "Preview unavailable for this file."
            errorMessage = error.localizedDescription
        }
    }

    func reveal(repositoryPath: String) {
        NSWorkspace.shared.activateFileViewerSelecting([
            URL(fileURLWithPath: repositoryPath)
        ])
    }

    func openInTerminal(repositoryPath: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: repositoryPath))
    }
}

