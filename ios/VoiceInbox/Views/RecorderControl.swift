import SwiftUI

/// The app's single input: the central record control (PROJECT.md §6.3).
///
/// Four states — Idle → Hold-to-record → Drag-to-lock → Stop/Cancel:
/// - Tap: start recording; tap again to stop and submit.
/// - Press and hold (≥0.35 s): record while held; release to stop and submit.
/// - Hold, then drag onto the lock icon: hands-free recording (locked).
/// - Locked: tap the central button to stop and submit; tap × to discard.
/// - Drag back to center mid-drag: abandon the lock, back to hold state.
///
/// Accessibility: the tap path alone covers start + stop, so VoiceOver and
/// motor-impaired users never need hold or drag.
struct RecorderControl: View {
    var recorder: AudioRecorderService
    var onFinished: (AudioRecorderService.Result) -> Void
    var onError: (String) -> Void

    private enum Kind: Equatable {
        case tapped
        case holding
        case locked
    }

    @State private var kind: Kind?
    @State private var dragOffset: CGSize = .zero
    @State private var isOverLock = false
    @GestureState private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let lockCenter = CGSize(width: 0, height: -130)
    private let lockHitRadius: CGFloat = 55

    private let appState = AppState.shared

    var body: some View {
        VStack(spacing: 12) {
            timerLabel
            waveform
            ZStack {
                lockTarget
                cancelButton
                mainButton
            }
            hintLabel
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 32)
        .background {
            // Local backdrop so cards scrolling behind never fight the HUD.
            // Display-only: must never swallow taps meant for cards underneath.
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(Color(.systemGroupedBackground).opacity(recorder.isRecording ? 0.0 : 0.72))
                .blur(radius: 18)
                .allowsHitTesting(false)
        }
        .animation(Motion.state, value: isOverLock)
        .onChange(of: appState.startToken) { _, _ in
            // App Shortcut / Action Button entry (PLAN-MVP.md #8).
            if kind == nil, !recorder.isRecording {
                handleTap()
            }
        }
    }

    // MARK: - Pieces

    private var timerLabel: some View {
        Text(recorder.isRecording ? formatted(recorder.elapsed) : " ")
            .font(.system(size: 26, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.primary)
            .opacity(recorder.isRecording ? 1 : 0)
            .accessibilityHidden(!recorder.isRecording)
            .allowsHitTesting(false)
    }

    private var waveform: some View {
        HStack(spacing: 3) {
            ForEach(Array(recorder.levelHistory.enumerated()), id: \.offset) { _, sample in
                Capsule()
                    .fill(Color.accent)
                    .frame(width: 3, height: 4 + CGFloat(sample) * 26)
            }
        }
        .frame(height: 32)
        .opacity(recorder.isRecording ? 1 : 0)
        .animation(.linear(duration: 0.1), value: recorder.levelHistory)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var lockTarget: some View {
        if kind == .holding {
            Image(systemName: isOverLock ? "lock.fill" : "lock.open")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isOverLock ? Color.onAccent : Color.secondary)
                .frame(width: 44, height: 44)
                .background(isOverLock ? Color.accent : Color(.secondarySystemGroupedBackground))
                .clipShape(Circle())
                .scaleEffect(isOverLock ? 1.15 : 1)
                .offset(lockCenter)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var cancelButton: some View {
        if kind == .locked {
            Button {
                Haptics.warning()
                recorder.cancel()
                withAnimation(Motion.respecting(reduceMotion, Motion.exit)) {
                    kind = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            .offset(CGSize(width: -110, height: 0))
            .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
            .accessibilityLabel("取消录音")
        }
    }

    private var mainButton: some View {
        ZStack {
            Circle()
                .fill(Color.accent.opacity(0.18))
                .frame(width: 104, height: 104)
                .scaleEffect(recorder.isRecording && !reduceMotion ? 1 + CGFloat(recorder.level) * 0.35 : 1)
                .animation(.linear(duration: 0.1), value: recorder.level)
            Circle()
                .fill(Color.accent)
                .frame(width: 80, height: 80)
                .shadow(color: Color.accent.opacity(0.35), radius: 12, y: 4)
            if recorder.isRecording {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.onAccent)
                    .frame(width: 26, height: 26)
            } else {
                Image(systemName: "mic.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.onAccent)
            }
        }
        .scaleEffect(isPressed ? 0.97 : 1)
        .animation(Motion.press, value: isPressed)
        .offset(effectiveDragOffset)
        .onTapGesture(perform: handleTap)
        .gesture(holdGesture)
        .simultaneousGesture(
            // Touch-down feedback: respond on press, not on release.
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in state = true }
        )
        .accessibilityLabel(recorder.isRecording ? "停止录音" : "录音")
        .accessibilityHint(recorder.isRecording ? "轻点停止并保存" : "轻点开始录音")
        .accessibilityAddTraits(.isButton)
    }

    private var hintLabel: some View {
        Text(hintText)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .allowsHitTesting(false)
    }

    private var hintText: String {
        switch kind {
        case nil: "轻点说话 · 长按持续录音"
        case .tapped: "再轻点一下停止"
        case .holding: isOverLock ? "松手锁定" : "松手发送 · 拖到锁图标可锁定"
        case .locked: "已锁定 · 轻点停止，点 × 取消"
        }
    }

    // MARK: - Gestures

    private func handleTap() {
        withAnimation(Motion.respecting(reduceMotion, Motion.state)) {
            switch kind {
            case nil:
                startRecording(as: .tapped)
            case .tapped, .locked:
                finish()
            case .holding:
                break
            }
        }
    }

    private var holdGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .first:
                    break
                case .second(true, let drag):
                    if kind == nil {
                        withAnimation(Motion.respecting(reduceMotion, Motion.state)) {
                            startRecording(as: .holding)
                        }
                    }
                    guard kind == .holding else { break }
                    if let drag {
                        dragOffset = drag.translation
                        let overLock = distance(drag.translation, lockCenter) < lockHitRadius
                        if overLock != isOverLock {
                            // Haptic fires on the same frame as the visual snap (harmony).
                            if overLock { Haptics.light() }
                            isOverLock = overLock
                        }
                    }
                default:
                    break
                }
            }
            .onEnded { _ in
                // Gesture release: the ride home carries momentum (slight bounce
                // is earned by the drag; reduced motion gets a plain cross-fade).
                withAnimation(Motion.respecting(reduceMotion, Motion.momentum)) {
                    defer {
                        dragOffset = .zero
                        isOverLock = false
                    }
                    guard kind == .holding else { return }
                    if isOverLock {
                        Haptics.rigid()
                        kind = .locked
                    } else {
                        finish()
                    }
                }
            }
    }

    // MARK: - Actions

    private func startRecording(as newKind: Kind) {
        Haptics.tap()
        kind = newKind
        Task {
            do {
                try await recorder.start()
            } catch {
                kind = nil
                onError(error.localizedDescription)
            }
        }
    }

    private func finish() {
        Haptics.rigid()
        kind = nil
        guard let result = recorder.stop() else { return }
        onFinished(result)
    }

    // MARK: - Helpers

    /// 1:1 tracking within the natural range, then rubber-banding — the
    /// further past the boundary, the less the button follows. Real things
    /// slow down before they stop; they don't hit invisible walls.
    private var effectiveDragOffset: CGSize {
        guard kind == .holding else { return .zero }
        let length = sqrt(dragOffset.width * dragOffset.width + dragOffset.height * dragOffset.height)
        guard length > 0 else { return .zero }
        let limit: CGFloat = 140
        let overshoot = max(0, length - limit)
        let extended = min(length, limit) + Motion.rubberband(overshoot)
        return CGSize(width: dragOffset.width / length * extended, height: dragOffset.height / length * extended)
    }

    private func distance(_ a: CGSize, _ b: CGSize) -> CGFloat {
        let dx = a.width - b.width
        let dy = a.height - b.height
        return sqrt(dx * dx + dy * dy)
    }

    private func formatted(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

#Preview {
    RecorderControl(recorder: AudioRecorderService(), onFinished: { _ in }, onError: { _ in })
}
