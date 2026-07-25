import Foundation
#if SWIFT_PACKAGE
import WorkbenchCore
#endif

public actor CodexCLIProvider: AgentProvider {
    public let id = "codex-cli"
    public let name = "Codex"

    private let executableURL: URL
    private let processRunner: any ProcessRunner
    private var executions: [UUID: Execution] = [:]

    private struct Execution {
        let id: UUID
        let task: Task<Void, Never>
    }

    public init(
        executableURL: URL = CodexCLIProvider.defaultExecutableURL(),
        processRunner: any ProcessRunner = LocalProcessRunner()
    ) {
        self.executableURL = executableURL
        self.processRunner = processRunner
    }

    public func execute(task: TaskSnapshot) async -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            let executionID = UUID()
            let execution = Task {
                do {
                    let result = try await processRunner.run(request(for: task))
                    guard !Task.isCancelled else {
                        continuation.finish()
                        return
                    }

                    emitEvents(from: result.standardOutputString, to: continuation)
                    emitStandardError(
                        result.standardErrorString,
                        failed: result.exitCode != 0,
                        to: continuation
                    )
                    continuation.yield(.finished(exitCode: Int(result.exitCode)))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
                finishExecution(taskID: task.id, executionID: executionID)
            }

            executions[task.id]?.task.cancel()
            executions[task.id] = Execution(id: executionID, task: execution)
            continuation.onTermination = { @Sendable _ in
                execution.cancel()
            }
        }
    }

    public func cancel(taskID: UUID) async {
        executions[taskID]?.task.cancel()
        executions[taskID] = nil
    }

    public static func defaultExecutableURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL {
        let pathCandidates = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0)).appending(path: "codex") }
        let knownCandidates = [
            URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
            URL(fileURLWithPath: "/usr/local/bin/codex")
        ]

        return (pathCandidates + knownCandidates).first {
            fileManager.isExecutableFile(atPath: $0.path)
        } ?? URL(fileURLWithPath: "/usr/bin/codex")
    }

    private func request(for task: TaskSnapshot) -> ProcessRequest {
        ProcessRequest(
            executableURL: executableURL,
            arguments: [
                "exec",
                "--json",
                "--color", "never",
                "--sandbox", "workspace-write",
                "--cd", task.repositoryPath,
                task.prompt
            ],
            currentDirectoryURL: URL(fileURLWithPath: task.repositoryPath)
        )
    }

    private func finishExecution(taskID: UUID, executionID: UUID) {
        guard executions[taskID]?.id == executionID else { return }
        executions[taskID] = nil
    }

    private func emitEvents(
        from output: String,
        to continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) {
        for line in output.split(whereSeparator: \.isNewline) {
            guard
                let data = String(line).data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                continuation.yield(.log(.info, String(line)))
                continue
            }
            emitEvent(from: object, to: continuation)
        }
    }

    private func emitEvent(
        from object: [String: Any],
        to continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) {
        let type = object["type"] as? String
        let item = object["item"] as? [String: Any]
        let itemType = item?["type"] as? String

        switch (type, itemType) {
        case ("thread.started", _):
            continuation.yield(.log(.info, "Codex session started"))
        case ("item.completed", "agent_message"):
            if let text = item?["text"] as? String, !text.isEmpty {
                continuation.yield(.log(.success, text))
            }
        case ("item.completed", "reasoning"):
            if let text = item?["text"] as? String, !text.isEmpty {
                continuation.yield(.log(.info, text))
            }
        case ("item.completed", "command_execution"):
            emitCommandEvent(item, to: continuation)
        case ("item.completed", "file_change"):
            emitFileChanges(item, to: continuation)
        case ("error", _):
            let message = object["message"] as? String ?? "Codex reported an error"
            continuation.yield(.log(.error, message))
        default:
            break
        }
    }

    private func emitCommandEvent(
        _ item: [String: Any]?,
        to continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) {
        guard let item else { return }
        if let command = item["command"] as? String, !command.isEmpty {
            continuation.yield(.log(.info, "$ \(command)"))
        }
        if let output = item["aggregated_output"] as? String, !output.isEmpty {
            let exitCode = item["exit_code"] as? Int
            continuation.yield(.log(exitCode == 0 ? .info : .error, output))
        }
    }

    private func emitFileChanges(
        _ item: [String: Any]?,
        to continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) {
        guard let changes = item?["changes"] as? [[String: Any]] else { return }
        for change in changes {
            if let path = change["path"] as? String {
                continuation.yield(.changedFile(path))
            }
        }
    }

    private func emitStandardError(
        _ standardError: String,
        failed: Bool,
        to continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) {
        for line in standardError.split(whereSeparator: \.isNewline) {
            continuation.yield(.log(failed ? .error : .warning, String(line)))
        }
    }
}
