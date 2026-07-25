import SwiftData
import SwiftUI
#if SWIFT_PACKAGE
import WorkbenchCore
#endif

struct SessionsView: View {
    @Bindable var model: AppViewModel
    @Query(sort: \AgentSession.startedAt, order: .reverse) private var sessions: [AgentSession]

    private var workspaceSessions: [AgentSession] {
        sessions.filter { $0.task?.workspace?.id == model.selectedWorkspace?.id }
    }

    var body: some View {
        if workspaceSessions.isEmpty {
            ContentUnavailableView(
                "No Sessions",
                systemImage: "bolt.horizontal.circle",
                description: Text("Run a task to create an agent session.")
            )
            .navigationTitle("Sessions")
        } else {
            List(workspaceSessions) { session in
                HStack(spacing: 12) {
                    Image(systemName: session.status == .running ? "dot.radiowaves.left.and.right" : "terminal")
                        .foregroundStyle(session.status.color)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.task?.title ?? "Untitled Task").fontWeight(.medium)
                        Text("\(session.agent) · \(session.startedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(session.changedFiles.count) files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    StatusBadge(status: session.status)
                }
                .padding(.vertical, 5)
            }
            .listStyle(.inset)
            .navigationTitle("Sessions")
        }
    }
}
