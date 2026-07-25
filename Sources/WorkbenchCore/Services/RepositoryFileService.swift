import Foundation

public struct RepositoryEntry: Identifiable, Hashable, Sendable {
    public let url: URL
    public let isDirectory: Bool

    public init(url: URL, isDirectory: Bool) {
        self.url = url
        self.isDirectory = isDirectory
    }

    public var id: URL { url }
    public var name: String { url.lastPathComponent }
}

public protocol RepositoryFileServing: Sendable {
    func entries(at repositoryURL: URL) async throws -> [RepositoryEntry]
    func contents(of entry: RepositoryEntry) async throws -> String
}

public actor RepositoryFileService: RepositoryFileServing {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func entries(at repositoryURL: URL) async throws -> [RepositoryEntry] {
        let urls = try fileManager.contentsOfDirectory(
            at: repositoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return try urls.map { url in
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            return RepositoryEntry(url: url, isDirectory: values.isDirectory ?? false)
        }
        .sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    public func contents(of entry: RepositoryEntry) async throws -> String {
        guard !entry.isDirectory else { return "" }
        return try String(contentsOf: entry.url, encoding: .utf8)
    }
}

