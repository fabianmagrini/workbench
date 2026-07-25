import SwiftData
import SwiftUI

struct HistoryView: View {
    @Bindable var model: AppModel
    @Query(sort: \AgentSession.startedAt, order: .reverse) private var sessions: [AgentSession]

    private var groupedSessions: [(Date, [AgentSession])] {
        let filtered = sessions.filter { $0.task?.workspace?.id == model.selectedWorkspace?.id }
        let grouped = Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.startedAt) }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        if groupedSessions.isEmpty {
            ContentUnavailableView(
                "No History",
                systemImage: "clock.arrow.circlepath",
                description: Text("Completed agent sessions appear here.")
            )
        } else {
            List {
                ForEach(groupedSessions, id: \.0) { day, sessions in
                    Section(day.formatted(date: .complete, time: .omitted)) {
                        ForEach(sessions) { session in
                            Button {
                                model.selectedTask = session.task
                                model.sidebarSelection = .tasks
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(session.task?.title ?? "Untitled Task").foregroundStyle(.primary)
                                        Text(session.startedAt, format: .dateTime.hour().minute())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    StatusBadge(status: session.status)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}
