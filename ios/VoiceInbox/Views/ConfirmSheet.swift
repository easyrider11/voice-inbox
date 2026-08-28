import SwiftUI
import SwiftData

/// Confirmation step (PROJECT.md §5.6): the AI result is a draft — the user can
/// edit fields, change the type, read the raw transcript, then save or discard.
struct ConfirmSheet: View {
    let capture: CaptureRecord

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private enum EditableIntent: String, CaseIterable, Identifiable {
        case todo
        case reminder
        case idea

        var id: String { rawValue }

        var label: String {
            switch self {
            case .todo: "待办"
            case .reminder: "提醒"
            case .idea: "想法"
            }
        }
    }

    private struct Line: Identifiable {
        let id = UUID()
        var text: String
    }

    @State private var intent: EditableIntent = .todo
    @State private var title = ""
    @State private var details = ""
    @State private var subtasks: [Line] = []
    @State private var bullets: [Line] = []
    @State private var fireDate = Date.now.addingTimeInterval(3600)
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("类型", selection: $intent) {
                        ForEach(EditableIntent.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    if let confidence = capture.confidence, capture.intentRaw == "unclassified" {
                        Text("AI 没有把握自动分类（置信度 \(Int(confidence * 100))%），请手动选择类型")
                    }
                }

                Section("内容") {
                    TextField("标题", text: $title)
                    switch intent {
                    case .todo:
                        TextField("说明", text: $details)
                        ForEach($subtasks) { $line in
                            TextField("子任务", text: $line.text)
                        }
                        .onDelete { subtasks.remove(atOffsets: $0) }
                        Button("添加子任务", systemImage: "plus") {
                            subtasks.append(Line(text: ""))
                        }
                    case .reminder:
                        DatePicker("提醒时间", selection: $fireDate)
                    case .idea:
                        ForEach($bullets) { $line in
                            TextField("要点", text: $line.text)
                        }
                        .onDelete { bullets.remove(atOffsets: $0) }
                        Button("添加要点", systemImage: "plus") {
                            bullets.append(Line(text: ""))
                        }
                    }
                }

                if let transcript = capture.transcript {
                    Section("原始转写") {
                        Text(transcript)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("删除这条捕捉", role: .destructive, action: discard)
                }
            }
            .navigationTitle("确认")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("稍后") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: confirm)
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .tint(.amber)
        .onAppear(perform: loadFromCapture)
    }

    // MARK: - Load

    private func loadFromCapture() {
        guard !loaded else { return }
        loaded = true

        let payload = capture.decodedPayload
        switch capture.intentRaw {
        case "reminder":
            intent = .reminder
        case "idea":
            intent = .idea
        default:
            intent = .todo
        }
        title = payload?.title ?? capture.transcript.map(firstClause) ?? ""
        details = payload?.details ?? ""
        subtasks = (payload?.subtasks ?? []).map(Line.init)
        bullets = (payload?.bullets ?? []).map(Line.init)
        if let fireAt = payload?.fireAt, let parsed = Self.parseISO(fireAt) {
            fireDate = parsed
        }
    }

    private func firstClause(_ text: String) -> String {
        text.components(separatedBy: CharacterSet(charactersIn: "，,。；;\n")).first ?? text
    }

    private static func parseISO(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }

    // MARK: - Actions

    private func confirm() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        switch intent {
        case .todo:
            let card = TodoCard(
                title: cleanTitle,
                details: details,
                subtasks: subtasks.map(\.text).filter { !$0.isEmpty }.map { Subtask(text: $0) }
            )
            card.sourceCaptureUUID = capture.uuid
            modelContext.insert(card)
        case .reminder:
            let card = ReminderCard(title: cleanTitle, fireDate: fireDate)
            card.sourceCaptureUUID = capture.uuid
            modelContext.insert(card)
            Task { await NotificationService.schedule(for: card) }
        case .idea:
            let card = IdeaCard(title: cleanTitle, bullets: bullets.map(\.text).filter { !$0.isEmpty })
            card.sourceCaptureUUID = capture.uuid
            modelContext.insert(card)
        }

        // Data minimization (PROJECT.md §11): the card is the artifact — drop the audio.
        if let filename = capture.audioFilename {
            AudioStore.delete(filename)
            capture.audioFilename = nil
        }
        capture.intentRaw = intent.rawValue
        capture.status = .saved
        try? modelContext.save()
        dismiss()
    }

    private func discard() {
        if let filename = capture.audioFilename {
            AudioStore.delete(filename)
        }
        modelContext.delete(capture)
        try? modelContext.save()
        dismiss()
    }
}
