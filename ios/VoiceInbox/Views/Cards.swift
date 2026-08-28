import SwiftUI

// Content cards for the inbox stream (PROJECT.md §6.4):
// vertical rectangular cards; To-do with checkable subtask rows,
// Reminder with a fire-time badge, Idea as an offset static stack.

// MARK: - To-do

struct TodoCardView: View {
    let card: TodoCard

    private var isCompleted: Bool { card.completedAt != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "checklist")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.amber)
                Text(card.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .strikethrough(isCompleted)
                Spacer()
            }
            if !card.details.isEmpty {
                Text(card.details)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(card.subtasks) { subtask in
                SubtaskRow(subtask: subtask) {
                    toggle(subtask)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(isCompleted ? 0.55 : 1)
    }

    private func toggle(_ subtask: Subtask) {
        var subtasks = card.subtasks
        guard let index = subtasks.firstIndex(where: { $0.id == subtask.id }) else { return }
        subtasks[index].done.toggle()
        card.subtasks = subtasks
        card.completedAt = subtasks.allSatisfy(\.done) && !subtasks.isEmpty ? .now : nil
    }
}

private struct SubtaskRow: View {
    let subtask: Subtask
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: subtask.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(subtask.done ? Color.amber : Color(.systemGray3))
                Text(subtask.text)
                    .font(.subheadline)
                    .foregroundStyle(subtask.done ? .secondary : .primary)
                    .strikethrough(subtask.done)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(subtask.done ? "取消完成 \(subtask.text)" : "完成 \(subtask.text)")
    }
}

// MARK: - Reminder

struct ReminderCardView: View {
    let card: ReminderCard
    var onToggleDone: () -> Void

    private var isOverdue: Bool { !card.done && card.fireDate < .now }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggleDone) {
                Image(systemName: card.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .foregroundStyle(card.done ? Color.amber : Color(.systemGray3))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(card.done ? "标记未完成" : "标记完成")

            VStack(alignment: .leading, spacing: 3) {
                Text(card.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .strikethrough(card.done)
                Text(formattedFireDate)
                    .font(.footnote)
                    .foregroundStyle(isOverdue ? .red : .secondary)
                    .monospacedDigit()
            }
            Spacer()
            Image(systemName: "bell.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.amber.opacity(card.done ? 0.4 : 1))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(card.done ? 0.55 : 1)
    }

    private var formattedFireDate: String {
        if Calendar.current.isDateInToday(card.fireDate) {
            return "今天 " + card.fireDate.formatted(date: .omitted, time: .shortened)
        }
        if Calendar.current.isDateInTomorrow(card.fireDate) {
            return "明天 " + card.fireDate.formatted(date: .omitted, time: .shortened)
        }
        return card.fireDate.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - Idea

struct IdeaCardView: View {
    let card: IdeaCard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.amber)
                Text(card.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            ForEach(Array(card.bullets.prefix(3).enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle()
                        .fill(Color.amber)
                        .frame(width: 5, height: 5)
                        .offset(y: -2)
                    Text(bullet)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if card.bullets.count > 3 {
                Text("还有 \(card.bullets.count - 3) 条要点")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Offset static stack (§6.4): the newest idea on top, edges of the cards
/// behind peeking out. Flip/swipe animation stays in the backlog; tapping
/// opens the full ideas list.
struct IdeaStackView: View {
    /// Newest first.
    let ideas: [IdeaCard]

    var body: some View {
        if let top = ideas.first {
            ZStack(alignment: .bottom) {
                if ideas.count > 2 {
                    stackLayer(scale: 0.90, offset: 16)
                }
                if ideas.count > 1 {
                    stackLayer(scale: 0.95, offset: 8)
                }
                IdeaCardView(card: top)
            }
            .padding(.bottom, ideas.count > 1 ? CGFloat(min(ideas.count - 1, 2)) * 8 : 0)
            .overlay(alignment: .topTrailing) {
                if ideas.count > 1 {
                    Text("\(ideas.count) 条想法")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.amber.opacity(0.15))
                        .foregroundStyle(Color.amber)
                        .clipShape(Capsule())
                        .padding(10)
                }
            }
        }
    }

    private func stackLayer(scale: CGFloat, offset: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .frame(height: 60)
            .scaleEffect(x: scale)
            .offset(y: offset)
            .opacity(0.7)
    }
}
