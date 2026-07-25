# Workbench Architecture

## Purpose

Workbench is a local-first native macOS control center for AI coding agents. It
coordinates work but does not replace an editor, terminal, Git host, or remote
execution environment.

`Workbench.xcodeproj` owns the distributable macOS application target,
application metadata, resources, signing configuration, and shared run scheme.
`Package.swift` provides a lightweight command-line build and the unit-test
target over the same source tree.

## Module boundaries

- `WorkbenchCore` owns SwiftData models, domain enums, and repository services.
  It has no dependency on UI or agent implementations.
- `WorkbenchAgents` owns the `AgentProvider` contract, sendable event values,
  and concrete providers. It depends only on `WorkbenchCore`.
- `WorkbenchUI` owns application orchestration, commands, styling, and SwiftUI
  features. It depends on Core and Agents.
- `WorkbenchApp` is the executable composition root. It creates the
  `ModelContainer` and installs the root view, Settings scene, and commands.

The dependency direction is:

```text
WorkbenchApp → WorkbenchUI → WorkbenchAgents → WorkbenchCore
                       └──────────────────────→ WorkbenchCore
```

The Xcode application target compiles the same files directly into the app
bundle, while SwiftPM enforces the module boundaries during command-line builds
and tests.

## Runtime shape

```text
WorkbenchApp
  ├─ ModelContainer (SwiftData)
  ├─ WorkbenchUI.WorkbenchRootView
  │    ├─ Sidebar
  │    ├─ Workspace content
  │    ├─ Task detail / live console
  │    └─ Inline inspector
  └─ AppModel (@MainActor)
       ├─ AgentProvider
       └─ SwiftData ModelContext
```

`WorkbenchApp` owns the shared SwiftData container. `AppModel` owns transient
selection and presentation state and coordinates asynchronous agent events with
persistent models. Views remain declarative and receive either `AppModel` or a
specific persistent model.

## Data model

- `Workspace` owns project identity, repository location, branch, preferred
  agent, tags, and tasks.
- `WorkbenchTask` owns its prompt, status, priority, labels, and sessions.
- `AgentSession` tracks one execution, including runtime state, exit code,
  changed files, and logs.
- `LogEntry` stores timestamped, leveled console output.

Relationships use cascade deletion so removing a workspace removes its tasks,
sessions, and logs. SwiftData is the source of truth for durable state.

## Agent execution

Every integration conforms to `AgentProvider`, a `Sendable` protocol:

1. `AppModel` creates an immutable `TaskSnapshot`.
2. The provider returns an `AsyncThrowingStream<AgentEvent, Error>`.
3. `AppModel` consumes the stream on the main actor.
4. Log, file, approval, and completion events update the active session.
5. SwiftData persists the resulting state.

`PreviewAgentProvider` is deterministic local scaffolding. A real CLI
integration should add a new actor conforming to `AgentProvider` and translate
process output into the existing event types.

## Concurrency boundaries

- `AppModel` is `@MainActor` because it mutates UI and SwiftData state.
- Agent and Git services are actors.
- Task snapshots and events are `Sendable` values crossing actor boundaries.
- One `Swift.Task` is retained per running Workbench task, enabling
  cancellation and preventing duplicate launches.

## User interface

The main window uses `NavigationSplitView` for native sidebar, content, and
detail behavior. The optional inspector is an inline trailing pane.

The inline design is intentional. The original system `.inspector` modifier
combined with a three-column `NavigationSplitView` triggered an AppKit
constraint-update loop on macOS 26.3. The inline pane preserves the same user
experience without the unstable nested window-layout behavior.

## Extension points

- Add agent integrations by implementing `AgentProvider`.
- Add repository operations behind `GitService`.
- Add durable model properties through a versioned SwiftData schema before
  production migrations are required.
- Keep process execution and parsing out of views.
- Keep credentials out of SwiftData; use Keychain-backed services when agent
  authentication is introduced.
