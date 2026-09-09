import SwiftUI
import SwiftData

/// Home screen (PROJECT.md §6.2):
/// large title → Smart Lists tiles → inbox stream (processing placeholders
/// pinned on top, then content cards reverse-chronological) → central record control.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \CaptureRecord.createdAt, order: .reverse) private var captures: [CaptureRecord]
    @Query(sort: \TodoCard.createdAt, order: .reverse) private var todos: [TodoCard]
    @Query(sort: \ReminderCard.createdAt, order: .reverse) private var reminders: [ReminderCard]
    @Query(sort: \IdeaCard.createdAt, order: .reverse) private var ideas: [IdeaCard]
    @Query private var meetings: [MeetingNote]

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false

    @State private var recorder = AudioRecorderService()
    @State private var player = AudioPlayerService()
    @State private var pipeline = CapturePipeline()
    @State private var confirming: CaptureRecord?
    @State private var editing: EditTarget?
    @State private var showingSettings = false
    @State private var pendingCardDelete: EditTarget?
    @State private var pendingCaptureDelete: CaptureRecord?
    @State private var failedCapture: CaptureRecord?
    @State private var errorMessage: String?
    @State private var serverHealth = ServerHealthMonitor()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if case .unreachable(let message) = serverHealth.state {
                            ServerStatusBanner(message: message) { showingSettings = true }
                        }
                        SmartListsGrid(
                            todayCount: todayCount,
                            todoCount: openTodoCount,
                            reminderCount: openReminderCount,
                            ideaCount: ideas.count
                        )
                        inboxStream
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 300)
                }
                .opacity(recorder.isRecording ? 0.12 : 1)
                .animation(.easeInOut(duration: 0.2), value: recorder.isRecording)
                .allowsHitTesting(!recorder.isRecording)
                RecorderControl(
                    recorder: recorder,
                    onFinished: saveCapture,
                    onError: { errorMessage = $0 }
                )
            }
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(for: InboxCategory.self) { category in
                CategoryListView(category: category, onEdit: { editing = $0 })
            }
        }
        .tint(.accent)
        .sheet(item: $confirming) { capture in
            ConfirmSheet(capture: capture)
        }
        .sheet(item: $editing) { target in
            CardEditorSheet(target: target)
        }
        .sheet(isPresented: $showingSettings, onDismiss: { Task { await serverHealth.check() } }) {
            SettingsView()
        }
        .fullScreenCover(isPresented: introBinding) {
            OnboardingView {
                hasSeenIntro = true
            }
        }
        .confirmationDialog(
            "Delete this card?",
            isPresented: cardDeleteBinding,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let target = pendingCardDelete {
                    deleteCard(target)
                }
                pendingCardDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingCardDelete = nil }
        }
        .confirmationDialog(
            "Delete this recording? The audio will be deleted too.",
            isPresented: captureDeleteBinding,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let capture = pendingCaptureDelete {
                    delete(capture)
                }
                pendingCaptureDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingCaptureDelete = nil }
        }
        .alert("This capture failed", isPresented: failedBinding, presenting: failedCapture) { capture in
            Button("Retry") { pipeline.run(capture, in: modelContext) }
            Button("Delete", role: .destructive) { delete(capture) }
            Button("OK", role: .cancel) {}
        } message: { capture in
            Text(capture.lastError ?? "Unknown error")
        }
        .alert("Can't record", isPresented: showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            NotificationService.updateBadge(with: reminders)
            await serverHealth.check()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active || phase == .background {
                NotificationService.updateBadge(with: reminders)
            }
            if phase == .active {
                Task { await serverHealth.check() }
            }
        }
        .onChange(of: reminderBadgeState) { _, _ in
            NotificationService.updateBadge(with: reminders)
        }
    }

    /// Changes whenever anything badge-relevant changes.
    private var reminderBadgeState: Int {
        reminders.reduce(0) { $0 &+ $1.fireDate.hashValue &+ ($1.done ? 1 : 0) }
    }

    private var introBinding: Binding<Bool> {
        Binding(get: { !hasSeenIntro }, set: { if !$0 { hasSeenIntro = true } })
    }

    private var cardDeleteBinding: Binding<Bool> {
        Binding(get: { pendingCardDelete != nil }, set: { if !$0 { pendingCardDelete = nil } })
    }

    private var failedBinding: Binding<Bool> {
        Binding(get: { failedCapture != nil }, set: { if !$0 { failedCapture = nil } })
    }

    private var captureDeleteBinding: Binding<Bool> {
        Binding(get: { pendingCaptureDelete != nil }, set: { if !$0 { pendingCaptureDelete = nil } })
    }

    // MARK: - Inbox stream

    /// Active captures stay pinned as placeholders; saved captures disappear
    /// behind the cards they produced.
    private var activeCaptures: [CaptureRecord] {
        captures.filter { $0.status != .saved }
    }

    private enum StreamEntry: Identifiable {
        case todo(TodoCard)
        case reminder(ReminderCard)
        case ideaStack([IdeaCard])

        var id: AnyHashable {
            switch self {
            case .todo(let card): AnyHashable(card.persistentModelID)
            case .reminder(let card): AnyHashable(card.persistentModelID)
            case .ideaStack: AnyHashable("idea-stack")
            }
        }

        var date: Date {
            switch self {
            case .todo(let card): card.createdAt
            case .reminder(let card): card.createdAt
            case .ideaStack(let cards): cards.first?.createdAt ?? .distantPast
            }
        }
    }

    private var streamEntries: [StreamEntry] {
        var entries: [StreamEntry] = []
        entries += todos.map(StreamEntry.todo)
        entries += reminders.map(StreamEntry.reminder)
        if !ideas.isEmpty {
            entries.append(.ideaStack(ideas))
        }
        return entries.sorted { $0.date > $1.date }
    }

    @ViewBuilder
    private var inboxStream: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.title3)
                .fontWeight(.bold)

            if activeCaptures.isEmpty && streamEntries.isEmpty {
                EmptyInboxCard()
            }

            ForEach(activeCaptures) { capture in
                CaptureRow(capture: capture, player: player, onRetry: {
                    pipeline.run(capture, in: modelContext)
                })
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .onTapGesture {
                        if capture.status == .awaitingConfirm {
                            confirming = capture
                        } else if capture.status == .failed {
                            failedCapture = capture
                        }
                    }
                    .contextMenu {
                        if capture.status == .failed {
                            Button("Retry", systemImage: "arrow.clockwise") {
                                pipeline.run(capture, in: modelContext)
                            }
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            pendingCaptureDelete = capture
                        }
                    }
                    .transition(.opacity)
            }

            ForEach(streamEntries) { entry in
                Group {
                    switch entry {
                    case .todo(let card):
                        TodoCardView(card: card)
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") { editing = .todo(card) }
                                Button("Delete", systemImage: "trash", role: .destructive) { pendingCardDelete = .todo(card) }
                            }
                    case .reminder(let card):
                        ReminderCardView(card: card) { toggleReminder(card) }
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") { editing = .reminder(card) }
                                Button("Delete", systemImage: "trash", role: .destructive) { pendingCardDelete = .reminder(card) }
                            }
                    case .ideaStack(let cards):
                        NavigationLink(value: InboxCategory.ideas) {
                            IdeaStackView(ideas: cards)
                        }
                        .buttonStyle(.plain)
                    }
                }
                // A confirmed capture lands as a card — the entrance keeps the
                // causal thread visible (never from scale 0; exit is faster).
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(insertion: Motion.cardInsertion, removal: .opacity)
                )
            }
        }
        .animation(Motion.respecting(reduceMotion, Motion.enter), value: streamKey)
    }

    /// Membership key for stream insert/remove transitions.
    private var streamKey: Int {
        activeCaptures.count &* 31 &+ streamEntries.count
    }

    // MARK: - Derived state

    private var showingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var openTodoCount: Int {
        todos.filter { $0.completedAt == nil }.count
    }

    private var openReminderCount: Int {
        reminders.filter { !$0.done }.count
    }

    private var todayCount: Int {
        let calendar = Calendar.current
        return reminders.filter { calendar.isDateInToday($0.fireDate) && !$0.done }.count
    }

    // MARK: - Actions

    private func saveCapture(_ result: AudioRecorderService.Result) {
        let capture = CaptureRecord(mode: .quick, status: .recorded)
        capture.audioFilename = result.filename
        capture.durationSec = result.duration
        modelContext.insert(capture)
        try? modelContext.save()
        pipeline.run(capture, in: modelContext)
    }

    private func delete(_ capture: CaptureRecord) {
        if let filename = capture.audioFilename {
            if player.playingFilename == filename {
                player.stop()
            }
            AudioStore.delete(filename)
        }
        modelContext.delete(capture)
        try? modelContext.save()
    }

    private func deleteCard(_ target: EditTarget) {
        switch target {
        case .todo(let card): modelContext.delete(card)
        case .reminder(let card):
            NotificationService.cancel(card.notificationID)
            modelContext.delete(card)
        case .idea(let card): modelContext.delete(card)
        }
        try? modelContext.save()
    }

    private func toggleReminder(_ card: ReminderCard) {
        card.done.toggle()
        if card.done {
            NotificationService.cancel(card.notificationID)
        } else {
            Task { await NotificationService.schedule(for: card) }
        }
        try? modelContext.save()
    }
}

// MARK: - Smart Lists

private struct SmartListsGrid: View {
    var todayCount: Int
    var todoCount: Int
    var reminderCount: Int
    var ideaCount: Int

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            SmartListTile(category: .today, count: todayCount, symbol: "sun.max.fill")
            SmartListTile(category: .todos, count: todoCount, symbol: "checklist")
            SmartListTile(category: .reminders, count: reminderCount, symbol: "bell.fill")
            SmartListTile(category: .ideas, count: ideaCount, symbol: "lightbulb.fill")
        }
    }
}

private struct SmartListTile: View {
    var category: InboxCategory
    var count: Int
    var symbol: String

    var body: some View {
        NavigationLink(value: category) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.accent)
                    Text(category.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Placeholders

private struct EmptyInboxCard: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("Nothing here yet")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("Tap the button and say a task, a reminder, or an idea")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CaptureRow: View {
    var capture: CaptureRecord
    var player: AudioPlayerService
    var onRetry: (() -> Void)?

    private var isPlaying: Bool {
        capture.audioFilename != nil && player.playingFilename == capture.audioFilename
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                if let filename = capture.audioFilename {
                    player.toggle(filename: filename)
                }
            } label: {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.onAccent)
                    .frame(width: 36, height: 36)
                    .background(Color.accent)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Stop playback" : "Play recording")

            VStack(alignment: .leading, spacing: 3) {
                Text(rowTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            Spacer()

            if capture.status == .failed, let onRetry {
                Button {
                    Haptics.tap()
                    onRetry()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accent)
                        .frame(width: 30, height: 30)
                        .background(Color.accent.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retry processing")
            }

            Text(statusLabel)
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(chipBackground)
                .foregroundStyle(chipForeground)
                .clipShape(Capsule())
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var rowTitle: String {
        if let title = capture.decodedPayload?.title, !title.isEmpty {
            return title
        }
        return String(localized: "Voice note")
    }

    private var subtitle: String {
        let meta = "\(formattedDuration) · \(capture.createdAt.formatted(date: .omitted, time: .shortened))"
        if capture.status == .awaitingConfirm {
            return meta + " · " + String(localized: "Tap to confirm")
        }
        if capture.status == .failed, let error = capture.lastError {
            return error + " · " + String(localized: "Tap for details")
        }
        return meta
    }

    private var formattedDuration: String {
        let total = Int(capture.durationSec ?? 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var statusLabel: String {
        switch capture.status {
        case .recorded: String(localized: "Queued")
        case .uploading: String(localized: "Uploading")
        case .processing: String(localized: "Processing")
        case .awaitingConfirm: String(localized: "To confirm")
        case .saved: String(localized: "Saved")
        case .failed: String(localized: "Failed")
        case .recording: String(localized: "Recording")
        }
    }

    private var chipBackground: Color {
        capture.status == .failed ? Color.red.opacity(0.12) : Color.accent.opacity(0.15)
    }

    private var chipForeground: Color {
        capture.status == .failed ? .red : .accent
    }
}

#Preview {
    HomeView()
        .modelContainer(
            for: [CaptureRecord.self, TodoCard.self, ReminderCard.self, IdeaCard.self, MeetingNote.self],
            inMemory: true
        )
}
