# Testing Workbench

## Commands

```sh
swift build
swift test
xcodebuild -project Workbench.xcodeproj -scheme Workbench \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Run the application with:

```sh
swift run Workbench
```

Apple's Xcode license must be accepted before using the Swift toolchain.

## Automated coverage

The test target uses Swift Testing and covers:

- stable task-status and priority definitions;
- in-memory SwiftData persistence and relationships;
- idempotent first-run seeding;
- task creation and selection;
- streamed log, changed-file, and completion events;
- task and session cancellation state;
- the preview provider's complete event sequence.

All persistence tests use `ModelConfiguration(isStoredInMemoryOnly: true)` and
do not affect the user's local Workbench database.

The tests import `WorkbenchCore`, `WorkbenchAgents`, and `WorkbenchUI`
independently. Accidental dependency leakage or missing public API surface
therefore fails at compile time.

## Manual launch smoke test

After automated tests pass:

1. Launch Workbench.
2. Confirm the main three-column window and inspector remain stable for at
   least ten seconds.
3. Select each sidebar section.
4. Create a task with `⌘N`.
5. Run it with `⌘R` and watch console and changed-file events.
6. Cancel a running task with `⌘.` and verify both task and session show
   `Cancelled`.
7. Toggle the inspector and resize the window.
8. Quit and relaunch to verify SwiftData persistence.

## Regression: inspector layout crash

A launch crash previously occurred when SwiftUI's `.inspector` modifier was
attached to the three-column split view. The macOS diagnostic reported repeated
`Update Constraints in Window` passes and an `NSGenericException`.

The inspector now renders as a trailing pane in the root `HStack`. The manual
smoke test must always include toggling the inspector and resizing the window.
If the system inspector is reconsidered, reproduce this scenario on the minimum
supported macOS version and the current macOS release before merging.
