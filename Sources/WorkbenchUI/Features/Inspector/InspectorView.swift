import SwiftUI
#if SWIFT_PACKAGE
import WorkbenchCore
#endif

struct InspectorView: View {
    let task: WorkbenchTask?

    var body: some View {
        if let task {
            Form {
                Section("Task Details") {
                    LabeledContent("Status") { StatusBadge(status: task.status) }
                    LabeledContent("Priority") {
                        Label(task.priority.rawValue, systemImage: "circle.fill")
                            .foregroundStyle(task.priority.color)
                    }
                    LabeledContent("Agent", value: task.agent)
                    LabeledContent("Workspace", value: task.workspace?.name ?? "—")
                }

                if let session = task.sessions.sorted(by: { $0.startedAt > $1.startedAt }).first {
                    Section("Latest Session") {
                        LabeledContent("Started") {
                            Text(session.startedAt, format: .dateTime.hour().minute().second())
                        }
                        LabeledContent("Runtime") {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Text(duration(from: session.startedAt, to: session.finishedAt ?? context.date))
                                    .monospacedDigit()
                            }
                        }
                        LabeledContent("Files", value: "\(session.changedFiles.count)")
                        if let exitCode = session.exitCode {
                            LabeledContent("Exit code", value: "\(exitCode)")
                        }
                    }

                    Section("Files Changed") {
                        ForEach(session.changedFiles.prefix(8), id: \.self) { file in
                            Label(file, systemImage: "doc.text")
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }

                Section("Metadata") {
                    LabeledContent("Created") { Text(task.createdAt, format: .dateTime) }
                    LabeledContent("Updated") {
                        Text(task.updatedAt, format: .relative(presentation: .named))
                    }
                    if !task.labels.isEmpty {
                        LabeledContent("Labels", value: task.labels.joined(separator: ", "))
                    }
                }
            }
            .formStyle(.grouped)
        } else {
            ContentUnavailableView("No Selection", systemImage: "sidebar.trailing")
        }
    }

    private func duration(from start: Date, to end: Date) -> String {
        let interval = max(0, Int(end.timeIntervalSince(start)))
        return String(format: "%02d:%02d", interval / 60, interval % 60)
    }
}
