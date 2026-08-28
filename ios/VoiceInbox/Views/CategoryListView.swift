import SwiftUI
import SwiftData

enum InboxCategory: String, Hashable {
    case today
    case todos
    case reminders
    case ideas

    var title: String {
        switch self {
        case .today: "今天"
        case .todos: "待办"
        case .reminders: "提醒"
        case .ideas: "想法"
        }
    }
}

/// Filtered list behind each Smart Lists tile (PROJECT.md §6.2).
struct CategoryListView: View {
    let category: InboxCategory
    var onEdit: (EditTarget) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoCard.createdAt, order: .reverse) private var todos: [TodoCard]
    @Query(sort: \ReminderCard.fireDate) private var reminders: [ReminderCard]
    @Query(sort: \IdeaCard.createdAt, order: .reverse) private var ideas: [IdeaCard]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 12) {
                    content
                }
                .padding(20)
            }
        }
        .navigationTitle(category.title)
    }

    @ViewBuilder
    private var content: some View {
        switch category {
        case .today:
            // Overdue first — unhandled things must stay visible (PLAN-MVP.md #7).
            let overdue = reminders.filter { !$0.done && $0.fireDate < .now && !Calendar.current.isDateInToday($0.fireDate) }
            let due = reminders.filter { Calendar.current.isDateInToday($0.fireDate) }
            if overdue.isEmpty && due.isEmpty {
                emptyText("今天没有到期的提醒")
            }
            if !overdue.isEmpty {
                sectionHeader("逾期")
                ForEach(overdue) { card in
                    reminderRow(card)
                }
            }
            if !due.isEmpty {
                if !overdue.isEmpty {
                    sectionHeader("今天")
                }
                ForEach(due) { card in
                    reminderRow(card)
                }
            }
        case .todos:
            if todos.isEmpty { emptyText("还没有待办") }
            ForEach(todos) { card in
                TodoCardView(card: card)
                    .contextMenu {
                        Button("编辑", systemImage: "pencil") { onEdit(.todo(card)) }
                        Button("删除", systemImage: "trash", role: .destructive) { delete(.todo(card)) }
                    }
            }
        case .reminders:
            if reminders.isEmpty { emptyText("还没有提醒") }
            ForEach(reminders) { card in
                reminderRow(card)
            }
        case .ideas:
            if ideas.isEmpty { emptyText("还没有想法") }
            ForEach(ideas) { card in
                IdeaCardView(card: card)
                    .contextMenu {
                        Button("编辑", systemImage: "pencil") { onEdit(.idea(card)) }
                        Button("删除", systemImage: "trash", role: .destructive) { delete(.idea(card)) }
                    }
            }
        }
    }

    private func reminderRow(_ card: ReminderCard) -> some View {
        ReminderCardView(card: card) {
            toggleReminder(card)
        }
        .contextMenu {
            Button("编辑", systemImage: "pencil") { onEdit(.reminder(card)) }
            Button("删除", systemImage: "trash", role: .destructive) { delete(.reminder(card)) }
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
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

    private func delete(_ target: EditTarget) {
        switch target {
        case .todo(let card): modelContext.delete(card)
        case .reminder(let card):
            NotificationService.cancel(card.notificationID)
            modelContext.delete(card)
        case .idea(let card): modelContext.delete(card)
        }
        try? modelContext.save()
    }
}
