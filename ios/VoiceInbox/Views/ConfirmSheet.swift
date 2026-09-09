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
            case .todo: String(localized: "To-do")
            case .reminder: String(localized: "Reminder")
            case .idea: String(localized: "Idea")
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
    @State private var showingDiscardConfirm = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $intent) {
                        ForEach(EditableIntent.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    if let confidence = capture.confidence, capture.intentRaw == "unclassified" {
                        Text("The AI wasn't confident about the type (\(Int(confidence * 100))%). Pick one.")
                    }
                }

                Section("Content") {
                    TextField("Title", text: $title)
                    switch intent {
                    case .todo:
                        TextField("Notes", text: $details)
                        ForEach($subtasks) { $line in
                            TextField("Subtask", text: $line.text)
                        }
                        .onDelete { subtasks.remove(atOffsets: $0) }
                        Button("Add Subtask", systemImage: "plus") {
                            subtasks.append(Line(text: ""))
                        }
                    case .reminder:
                        DatePicker("Remind at", selection: $fireDate)
                    case .idea:
                        ForEach($bullets) { $line in
                            TextField("Point", text: $line.text)
                        }
                        .onDelete { bullets.remove(atOffsets: $0) }
                        Button("Add Point", systemImage: "plus") {
                            bullets.append(Line(text: ""))
                        }
                    }
                }

                if let transcript = capture.transcript {
                    Section("Original Transcript") {
                        Text(transcript)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Delete This Capture", role: .destructive) {
                        showingDiscardConfirm = true
                    }
                }
            }
            .navigationTitle("Confirm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: confirm)
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .tint(.accent)
        .confirmationDialog(
            "Delete this capture? The recording and transcript will be deleted.",
            isPresented: $showingDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: discard)
            Button("Cancel", role: .cancel) {}
        }
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
        Haptics.success()
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
