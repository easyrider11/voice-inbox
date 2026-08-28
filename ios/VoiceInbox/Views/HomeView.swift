import SwiftUI
import SwiftData

/// Home screen skeleton (PROJECT.md §6.2):
/// large title → Smart Lists tiles → inbox stream → central record button.
struct HomeView: View {
    @Query private var todos: [TodoCard]
    @Query private var reminders: [ReminderCard]
    @Query private var ideas: [IdeaCard]
    @Query private var meetings: [MeetingNote]

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
                        InboxSection(isEmpty: inboxIsEmpty)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 220)
                }
                VStack(spacing: 12) {
                    RecordButton(action: startQuickCapture)
                    Text("轻点说话")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("收件箱")
        }
        .tint(.amber)
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

    private var inboxIsEmpty: Bool {
        todos.isEmpty && reminders.isEmpty && ideas.isEmpty && meetings.isEmpty
    }

    private func startQuickCapture() {
        // M1: enter the four-state recording flow (PROJECT.md §6.3).
    }
}

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

private struct InboxSection: View {
    var isEmpty: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近")
                .font(.title3)
                .fontWeight(.bold)
            if isEmpty {
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
            // M3: vertical content cards — To-do / Reminder / Idea / Meeting (PROJECT.md §6.4).
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
