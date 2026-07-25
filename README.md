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

The native source is under `Sources/Workbench`. Open `Workbench.xcodeproj` in
Xcode and run the shared `Workbench` application scheme. `Package.swift`
remains available for command-line builds and unit tests.

The MVP includes local workspace and task persistence, native three-column
navigation, an inspector, task creation and filtering, a streaming
agent-provider abstraction, live logs, changed files, session history,
repository browsing, Settings, and keyboard commands.

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
```

Xcode’s license must be accepted on the development Mac before Apple’s Swift
toolchain can compile the package.

## Documentation

- [Product specification](docs/initial-spec.md)
- [Architecture and extension points](docs/ARCHITECTURE.md)
- [Automated and manual testing](docs/TESTING.md)

## Project layout

```text
Sources/Workbench/
  App/          Application entry point and orchestration state
  Models/       SwiftData models and domain enums
  Services/     Agent and Git service boundaries
  Features/     SwiftUI feature views
tests/
  WorkbenchTests/
docs/
```
