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
                    .foregroundStyle(Color.accent)
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
        subtasks[index].done ? Haptics.light() : Haptics.tap()
        card.subtasks = subtasks
        let allDone = subtasks.allSatisfy(\.done) && !subtasks.isEmpty
        if allDone, card.completedAt == nil {
            Haptics.success()
        }
        card.completedAt = allDone ? .now : nil
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
                    .foregroundStyle(subtask.done ? Color.accent : Color(.systemGray3))
                Text(subtask.text)
                    .font(.subheadline)
                    .foregroundStyle(subtask.done ? .secondary : .primary)
                    .strikethrough(subtask.done)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(subtask.done ? "Mark \(subtask.text) not done" : "Mark \(subtask.text) done")
    }
}

// MARK: - Reminder

struct ReminderCardView: View {
    let card: ReminderCard
    var onToggleDone: () -> Void

    private var isOverdue: Bool { !card.done && card.fireDate < .now }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.light()
                onToggleDone()
            } label: {
                Image(systemName: card.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .foregroundStyle(card.done ? Color.accent : Color(.systemGray3))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(card.done ? "Mark not done" : "Mark done")

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
                .foregroundStyle(Color.accent.opacity(card.done ? 0.4 : 1))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(card.done ? 0.55 : 1)
    }

    private var formattedFireDate: String {
        if Calendar.current.isDateInToday(card.fireDate) {
            return String(localized: "Today") + " " + card.fireDate.formatted(date: .omitted, time: .shortened)
        }
        if Calendar.current.isDateInTomorrow(card.fireDate) {
            return String(localized: "Tomorrow") + " " + card.fireDate.formatted(date: .omitted, time: .shortened)
        }
        return card.fireDate.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - Idea

struct IdeaCardView: View {
    let card: IdeaCard
    /// When shown as the top of a stack, the total idea count (badge inline in
    /// the header so it never covers content).
    var stackCount: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accent)
                Text(card.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                Spacer()
                if let stackCount, stackCount > 1 {
                    Text("\(stackCount) ideas")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accent.opacity(0.15))
                        .foregroundStyle(Color.accent)
                        .clipShape(Capsule())
                }
            }
            ForEach(Array(card.bullets.prefix(3).enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle()
                        .fill(Color.accent)
                        .frame(width: 5, height: 5)
                        .offset(y: -2)
                    Text(bullet)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if card.bullets.count > 3 {
                Text("\(card.bullets.count - 3) more points")
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

/// Offset stack (§6.4), now interactive (B12): swipe the top idea sideways to
/// flip to the next one — the cards behind rise into place as you drag,
/// telegraphing where things are going. Tap still opens the full ideas list.
///
/// Feel rules (apple-design): 1:1 tracking while dragging, momentum decides
/// commit (a flick is enough), the release spring carries velocity, and the
/// cards behind hint the outcome. Reduced motion: instant swap, no rotation.
struct IdeaStackView: View {
    /// Newest first.
    let ideas: [IdeaCard]

    @State private var topSlot = 0
    @State private var dragX: CGFloat = 0
    @State private var isFlying = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var count: Int { ideas.count }

    private func idea(at slot: Int) -> IdeaCard {
        ideas[(topSlot + slot) % count]
    }

    /// 0…1 — how far the swipe has committed; drives the rise of the stack.
    private var progress: CGFloat {
        min(1, abs(dragX) / 160)
    }

    var body: some View {
        if !ideas.isEmpty {
            ZStack(alignment: .bottom) {
                if count > 2 {
                    behindCard(idea(at: 2), fromScale: 0.90, toScale: 0.95, fromOffset: 16, toOffset: 8)
                }
                if count > 1 {
                    behindCard(idea(at: 1), fromScale: 0.95, toScale: 1.0, fromOffset: 8, toOffset: 0)
                }
                topCard
            }
            .padding(.bottom, count > 1 ? CGFloat(min(count - 1, 2)) * 8 : 0)
        }
    }

    private var topCard: some View {
        IdeaCardView(card: idea(at: 0), stackCount: count)
            .offset(x: dragX)
            .rotationEffect(
                reduceMotion ? .zero : .degrees(Double(dragX / 22)),
                anchor: .bottom
            )
            .gesture(count > 1 ? swipeGesture : nil)
            .accessibilityHint(count > 1 ? "Swipe left or right for the next idea" : "")
    }

    private func behindCard(
        _ card: IdeaCard,
        fromScale: CGFloat, toScale: CGFloat,
        fromOffset: CGFloat, toOffset: CGFloat
    ) -> some View {
        IdeaCardView(card: card)
            .scaleEffect(fromScale + (toScale - fromScale) * progress)
            .offset(y: fromOffset + (toOffset - fromOffset) * progress)
            .opacity(0.7 + 0.3 * progress)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                guard !isFlying else { return }
                // Direct manipulation: the card stays glued to the finger.
                dragX = value.translation.width
            }
            .onEnded { value in
                guard !isFlying else { return }
                // Momentum projection: commit based on where the gesture is
                // going, not just where it stopped — a quick flick is enough.
                let projected = value.predictedEndTranslation.width
                let commits = abs(projected) > 140 || abs(dragX) > 120

                if !commits {
                    withAnimation(Motion.respecting(reduceMotion, Motion.momentum)) {
                        dragX = 0
                    }
                    return
                }

                if reduceMotion {
                    topSlot = (topSlot + 1) % count
                    dragX = 0
                    Haptics.light()
                    return
                }

                // Fly out with the gesture's momentum; when the card lands,
                // the risen behind-card occupies exactly the top slot, so the
                // index swap happens on an identical frame — no visible cut.
                isFlying = true
                let direction: CGFloat = dragX >= 0 ? 1 : -1
                withAnimation(Motion.momentum) {
                    dragX = direction * 560
                } completion: {
                    topSlot = (topSlot + 1) % count
                    dragX = 0
                    isFlying = false
                    Haptics.light()
                }
            }
    }
}
