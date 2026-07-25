import Foundation
import Observation
#if SWIFT_PACKAGE
import WorkbenchCore
#endif

@MainActor
@Observable
final class NewTaskViewModel {
    var title = ""
    var prompt = ""
    var agent = "Codex"
    var priority: TaskPriority = .medium

    let agents = ["Codex", "Claude Code", "Amp", "Gemini CLI"]

    var canCreate: Bool {
        !normalizedTitle.isEmpty && !normalizedPrompt.isEmpty
    }

    var input: NewTaskInput {
        NewTaskInput(
            title: normalizedTitle,
            prompt: normalizedPrompt,
            agent: agent,
            priority: priority
        )
    }

    private var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
