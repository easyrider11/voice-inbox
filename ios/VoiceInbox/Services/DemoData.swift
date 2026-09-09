import Foundation
import SwiftData

/// DEBUG-only screenshot fixture. Launch with `--demo-data` to replace the
/// local store with English sample cards. Never compiled into Release.
enum DemoData {
    static var requested: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--demo-data")
        #else
        false
        #endif
    }

    @MainActor
    static func seedIfRequested(in context: ModelContext) {
        #if DEBUG
        guard requested else { return }
        for record in (try? context.fetch(FetchDescriptor<CaptureRecord>())) ?? [] { context.delete(record) }
        for card in (try? context.fetch(FetchDescriptor<TodoCard>())) ?? [] { context.delete(card) }
        for card in (try? context.fetch(FetchDescriptor<ReminderCard>())) ?? [] { context.delete(card) }
        for card in (try? context.fetch(FetchDescriptor<IdeaCard>())) ?? [] { context.delete(card) }

        let now = Date.now
        let todo = TodoCard(
            title: "Three things to do today",
            subtasks: [
                Subtask(text: "Send the project doc to my cofounder"),
                Subtask(text: "Finish the upload code", done: true),
                Subtask(text: "Gym for an hour tonight"),
            ],
            createdAt: now.addingTimeInterval(-3600)
        )
        let reminder = ReminderCard(
            title: "Call the dentist",
            fireDate: Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: now) ?? now,
            createdAt: now.addingTimeInterval(-1800)
        )
        let idea1 = IdeaCard(
            title: "Turn the inbox into an MCP server",
            bullets: ["Let other AI tools write into it", "One hub for tasks and ideas"],
            createdAt: now.addingTimeInterval(-900)
        )
        let idea2 = IdeaCard(
            title: "Waveform on the record button",
            bullets: ["Bars follow the voice level while recording"],
            createdAt: now.addingTimeInterval(-300)
        )
        for model in [todo, reminder, idea1, idea2] as [any PersistentModel] { context.insert(model) }
        try? context.save()
        #endif
    }
}
