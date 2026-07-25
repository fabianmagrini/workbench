# Workbench Contributor Guide

## Project

Workbench is a native macOS control center for running and monitoring local AI
coding agents. The product specification is in `docs/initial-spec.md`.

Requirements:

- macOS 15 or later
- Swift 6
- Xcode with its license accepted
- Codex CLI installed and authenticated for production agent execution

## Repository layout

```text
Sources/WorkbenchApp/       Application composition root
Sources/WorkbenchCore/      Models and local system services
Sources/WorkbenchAgents/    Agent contracts, providers, and orchestration
Sources/WorkbenchUI/        SwiftUI application and feature views
Resources/                  Application assets
tests/WorkbenchTests/       Swift Testing unit and integration tests
tests/WorkbenchUITests/     XCTest macOS UI tests
docs/                       Specification, architecture, and testing guides
```

Read `docs/ARCHITECTURE.md` before changing module boundaries and
`docs/TESTING.md` before modifying test infrastructure.

## Architecture rules

- Dependencies flow from `WorkbenchApp` to `WorkbenchUI`, then to
  `WorkbenchAgents`, then to `WorkbenchCore`.
- `WorkbenchUI` may also depend directly on `WorkbenchCore`.
- `WorkbenchCore` must not depend on UI or agent implementations.
- Keep SwiftData and UI mutations on the main actor.
- Cross-actor values must conform to `Sendable`.
- Views remain declarative. Put process execution, parsing, persistence
  coordination, and session lifecycle logic in their respective services.
- Add agent integrations through `AgentProvider`.
- Run local commands through `ProcessRunner`; do not introduce shell execution
  directly into views.
- Keep credentials out of SwiftData and source control.

## Xcode and SwiftPM

The Xcode application target compiles source files directly, while
`Package.swift` enforces module boundaries and provides unit tests.

When adding, moving, or deleting a source file:

1. Update its SwiftPM target when needed.
2. Update `Workbench.xcodeproj/project.pbxproj` file references and build
   phases.
3. Confirm both `swift test` and the Xcode build succeed.

The `WorkbenchUITests` target is owned by Xcode and is included in the shared
`Workbench` scheme.

## Validation

Run the checks relevant to the change:

```sh
swift test
xcodebuild -project Workbench.xcodeproj -scheme Workbench \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
xcodebuild test -project Workbench.xcodeproj -scheme Workbench \
  -destination 'platform=macOS'
git diff --check
```

Current expected coverage is 15 Swift Testing tests across five suites and two
macOS UI tests. Update `docs/TESTING.md` when those totals or commands change.

UI tests require an interactive macOS login session. They launch with
`--ui-testing`, use an in-memory SwiftData store, and select
`PreviewAgentProvider`. Never let UI tests invoke an authenticated Codex
session or modify the user's persistent Workbench database.

## Agent execution safety

- Production Codex tasks use `codex exec --json` with `workspace-write`.
- Do not add approval or sandbox bypass flags.
- Preserve separate stdout and stderr diagnostics.
- Ensure task cancellation terminates its child process.
- Treat repository paths and prompts as arguments, not shell fragments.
- Add deterministic tests for command construction, output parsing, failures,
  and cancellation whenever an agent provider changes.

## Documentation

Keep these files aligned with behavior:

- `README.md` for setup, capabilities, commands, and current limitations
- `docs/ARCHITECTURE.md` for ownership and dependency decisions
- `docs/TESTING.md` for automated coverage and manual regression checks

Document known limitations honestly. Do not describe buffered process output as
incremental streaming or metadata-only agent selection as provider routing.
