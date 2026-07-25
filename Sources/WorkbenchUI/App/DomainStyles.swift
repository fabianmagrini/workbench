import SwiftUI
#if SWIFT_PACKAGE
import WorkbenchCore
#endif

extension TaskStatus {
    var color: Color {
        switch self {
        case .draft, .queued: .secondary
        case .running: .green
        case .waitingApproval: .orange
        case .failed, .cancelled: .red
        case .completed: .blue
        }
    }
}

extension TaskPriority {
    var color: Color {
        switch self {
        case .low: .secondary
        case .medium: .orange
        case .high: .red
        }
    }
}
