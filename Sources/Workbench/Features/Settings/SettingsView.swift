import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultAgent") private var defaultAgent = "Codex"
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("confirmBeforeRunning") private var confirmBeforeRunning = false

    var body: some View {
        TabView {
            Form {
                Picker("Default agent", selection: $defaultAgent) {
                    ForEach(["Codex", "Claude Code", "Amp", "Gemini CLI"], id: \.self) {
                        Text($0)
                    }
                }
                Toggle("Confirm before running tasks", isOn: $confirmBeforeRunning)
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gear") }

            Form {
                Toggle("Show completion notifications", isOn: $showNotifications)
                Text("Workbench stores task and session data locally on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            .tabItem { Label("Notifications", systemImage: "bell") }
        }
        .frame(width: 520, height: 280)
    }
}
