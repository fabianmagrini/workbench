import Foundation

public struct ProcessRequest: Sendable, Equatable {
    public var executableURL: URL
    public var arguments: [String]
    public var currentDirectoryURL: URL?
    public var environment: [String: String]?

    public init(
        executableURL: URL,
        arguments: [String] = [],
        currentDirectoryURL: URL? = nil,
        environment: [String: String]? = nil
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.currentDirectoryURL = currentDirectoryURL
        self.environment = environment
    }
}

public struct ProcessResult: Sendable, Equatable {
    public let standardOutput: Data
    public let standardError: Data
    public let exitCode: Int32
    public let terminationReason: Process.TerminationReason

    public init(
        standardOutput: Data,
        standardError: Data,
        exitCode: Int32,
        terminationReason: Process.TerminationReason
    ) {
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.exitCode = exitCode
        self.terminationReason = terminationReason
    }

    public var standardOutputString: String {
        String(decoding: standardOutput, as: UTF8.self)
    }

    public var standardErrorString: String {
        String(decoding: standardError, as: UTF8.self)
    }
}

public protocol ProcessRunner: Sendable {
    func run(_ request: ProcessRequest) async throws -> ProcessResult
}

public actor LocalProcessRunner: ProcessRunner {
    private var runningProcesses: [UUID: Process] = [:]

    public init() {}

    public func run(_ request: ProcessRequest) async throws -> ProcessResult {
        try Task.checkCancellation()

        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        let processID = UUID()

        process.executableURL = request.executableURL
        process.arguments = request.arguments
        process.currentDirectoryURL = request.currentDirectoryURL
        process.environment = request.environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        runningProcesses[processID] = process
        defer { runningProcesses[processID] = nil }

        return try await withTaskCancellationHandler {
            async let outputData = standardOutput.fileHandleForReading.readToEnd() ?? Data()
            async let errorData = standardError.fileHandleForReading.readToEnd() ?? Data()

            await waitForTermination(of: process)
            let result = try await ProcessResult(
                standardOutput: outputData,
                standardError: errorData,
                exitCode: process.terminationStatus,
                terminationReason: process.terminationReason
            )
            return result
        } onCancel: {
            Task { await self.terminate(processID: processID) }
        }
    }

    private func waitForTermination(of process: Process) async {
        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }
    }

    private func terminate(processID: UUID) {
        guard let process = runningProcesses[processID], process.isRunning else {
            return
        }
        process.terminate()
    }
}
