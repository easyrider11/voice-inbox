import SwiftUI
import SwiftData

/// Home screen (PROJECT.md §6.2):
/// large title → Smart Lists tiles → inbox stream → central record control.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CaptureRecord.createdAt, order: .reverse) private var captures: [CaptureRecord]
    @Query private var todos: [TodoCard]
    @Query private var reminders: [ReminderCard]
    @Query private var ideas: [IdeaCard]
    @Query private var meetings: [MeetingNote]

    @State private var recorder = AudioRecorderService()
    @State private var player = AudioPlayerService()
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        SmartListsGrid(
                            todayCount: todayCount,
                            todoCount: openTodoCount,
                            reminderCount: openReminderCount,
                            ideaCount: ideas.count
                        )
                        InboxSection(captures: captures, player: player, onDelete: delete)
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
            .navigationTitle("收件箱")
        }
        .tint(.amber)
        .alert("无法录音", isPresented: showingError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
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
            SmartListTile(title: "今天", count: todayCount, symbol: "sun.max.fill")
            SmartListTile(title: "待办", count: todoCount, symbol: "checklist")
            SmartListTile(title: "提醒", count: reminderCount, symbol: "bell.fill")
            SmartListTile(title: "想法", count: ideaCount, symbol: "lightbulb.fill")
        }
    }
}

private struct SmartListTile: View {
    var title: String
    var count: Int
    var symbol: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.amber)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(count)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Inbox stream

private struct InboxSection: View {
    var captures: [CaptureRecord]
    var player: AudioPlayerService
    var onDelete: (CaptureRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近")
                .font(.title3)
                .fontWeight(.bold)
            if captures.isEmpty {
                EmptyInboxCard()
            } else {
                ForEach(captures) { capture in
                    CaptureRow(capture: capture, player: player)
                        .contextMenu {
                            Button("删除", systemImage: "trash", role: .destructive) {
                                onDelete(capture)
                            }
                        }
                }
            }
            // M3: To-do / Reminder / Idea / Meeting content cards (PROJECT.md §6.4).
        }
    }
}

private struct EmptyInboxCard: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("还没有内容")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("轻点中间的按钮，说出要做的事、提醒或想法")
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
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.amber)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "停止播放" : "播放录音")

            VStack(alignment: .leading, spacing: 3) {
                Text("语音速记")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(formattedDuration) · \(capture.createdAt.formatted(date: .omitted, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Text(statusLabel)
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.amber.opacity(0.15))
                .foregroundStyle(Color.amber)
                .clipShape(Capsule())
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var formattedDuration: String {
        let total = Int(capture.durationSec ?? 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var statusLabel: String {
        switch capture.status {
        case .recorded: "待处理"
        case .uploading: "上传中"
        case .processing: "整理中"
        case .awaitingConfirm: "待确认"
        case .saved: "已保存"
        case .failed: "失败"
        case .recording: "录音中"
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(
            for: [CaptureRecord.self, TodoCard.self, ReminderCard.self, IdeaCard.self, MeetingNote.self],
            inMemory: true
        )
}
