# Workbench

Workbench is a native macOS control center for orchestrating, monitoring, and
reviewing AI coding agents. It follows the product definition in
`docs/initial-spec.md`.

## Native application

- Swift 6
- SwiftUI
- SwiftData
- async/await and actors
- Swift Package Manager
- macOS 15+

The native source is split across the modules under `Sources/`. Open
`Workbench.xcodeproj` in Xcode and run the shared `Workbench` application
scheme. `Package.swift` remains available for command-line builds and unit
tests.

The MVP includes local workspace and task persistence, native three-column
navigation, an inspector, task creation and filtering, a streaming
agent-provider abstraction, live logs, changed files, session history,
repository browsing, Settings, and keyboard commands.

## Requirements

- macOS 15 or later;
- Xcode with its license accepted;
- Codex CLI installed and authenticated for production task execution.

Workbench resolves `codex` from `PATH`, `/opt/homebrew/bin`, or
`/usr/local/bin`. Agent commands run in the selected repository with Codex's
`workspace-write` sandbox. Workbench does not use sandbox or approval bypass
flags.

## Keyboard shortcuts

- `⌘N` — New Task
- `⌘R` — Run selected task
- `⌘.` — Cancel selected task
- `⌘F` — Search
- `⌘,` — Settings

## Building

```sh
swift build
swift test
xcodebuild -project Workbench.xcodeproj -scheme Workbench \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
xcodebuild test -project Workbench.xcodeproj -scheme Workbench \
  -destination 'platform=macOS'
```

`swift test` runs the 15 domain, orchestration, process, and provider tests.
The Xcode test command builds, launches, and drives the two macOS UI tests.
Those tests use an in-memory database and deterministic preview provider; they
do not modify the user's Workbench data or start an authenticated Codex task.

## Current integration scope

- Codex CLI is the only production agent provider.
- The agent picker is persisted as task metadata; provider routing for Claude
  Code, Amp, and Gemini CLI is not implemented yet.
- Codex JSONL output is currently parsed after the child process exits. True
  incremental process-output streaming remains future work.
- Interactive approval responses are not yet surfaced in the Workbench UI.


## Documentation

- [Product specification](docs/initial-spec.md)
- [Architecture and extension points](docs/ARCHITECTURE.md)
- [Automated and manual testing](docs/TESTING.md)

## Project layout

```text
Sources/WorkbenchApp/
  WorkbenchApp.swift   Thin executable and scene composition
Sources/WorkbenchCore/
  Models/              SwiftData models and domain enums
  Services/            Local repository services
Sources/WorkbenchAgents/
  AgentProvider.swift       Agent contract, events, and preview provider
  CodexCLIProvider.swift    Production Codex CLI integration
  SessionOrchestrator.swift Session lifecycle and event reduction
Sources/WorkbenchUI/
  App/                 UI orchestration, commands, and domain styling
  Features/            SwiftUI feature views
tests/
  WorkbenchTests/      Swift Testing unit and integration suite
  WorkbenchUITests/    XCTest launch and workflow UI suite
docs/
```
