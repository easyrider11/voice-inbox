import SwiftUI
import SwiftData

/// Which saved card is being edited (三类卡片可增删改 — the "改").
enum EditTarget: Identifiable {
    case todo(TodoCard)
    case reminder(ReminderCard)
    case idea(IdeaCard)

    var id: PersistentIdentifier {
        switch self {
        case .todo(let card): card.persistentModelID
        case .reminder(let card): card.persistentModelID
        case .idea(let card): card.persistentModelID
        }
    }
}

struct CardEditorSheet: View {
    let target: EditTarget

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private struct Line: Identifiable {
        let id = UUID()
        var text: String
        var done = false
    }

    @State private var title = ""
    @State private var details = ""
    @State private var lines: [Line] = []
    @State private var fireDate = Date.now
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("内容") {
                    TextField("标题", text: $title)
                    switch target {
                    case .todo:
                        TextField("说明", text: $details)
                        ForEach($lines) { $line in
                            TextField("子任务", text: $line.text)
                        }
                        .onDelete { lines.remove(atOffsets: $0) }
                        Button("添加子任务", systemImage: "plus") {
                            lines.append(Line(text: ""))
                        }
                    case .reminder:
                        DatePicker("提醒时间", selection: $fireDate)
                    case .idea:
                        ForEach($lines) { $line in
                            TextField("要点", text: $line.text)
                        }
                        .onDelete { lines.remove(atOffsets: $0) }
                        Button("添加要点", systemImage: "plus") {
                            lines.append(Line(text: ""))
                        }
                    }
                }
            }
            .navigationTitle("编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .tint(.amber)
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch target {
        case .todo(let card):
            title = card.title
            details = card.details
            lines = card.subtasks.map { Line(text: $0.text, done: $0.done) }
        case .reminder(let card):
            title = card.title
            fireDate = card.fireDate
        case .idea(let card):
            title = card.title
            lines = card.bullets.map { Line(text: $0) }
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        switch target {
        case .todo(let card):
            card.title = cleanTitle
            card.details = details
            card.subtasks = lines
                .filter { !$0.text.isEmpty }
                .map { Subtask(text: $0.text, done: $0.done) }
            card.completedAt = !card.subtasks.isEmpty && card.subtasks.allSatisfy(\.done) ? .now : nil
        case .reminder(let card):
            card.title = cleanTitle
            card.fireDate = fireDate
            Task { await NotificationService.schedule(for: card) }
        case .idea(let card):
            card.title = cleanTitle
            card.bullets = lines.map(\.text).filter { !$0.isEmpty }
        }
        try? modelContext.save()
        dismiss()
    }
}
