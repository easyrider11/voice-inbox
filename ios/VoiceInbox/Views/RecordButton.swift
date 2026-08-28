import SwiftUI

/// The app's single input: the central record button (PROJECT.md §6.3).
/// M0 renders the idle state only; the four-state gesture machine
/// (tap / hold / drag-to-lock / stop-cancel) lands in M1.
struct RecordButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.amber.opacity(0.18))
                    .frame(width: 104, height: 104)
                Circle()
                    .fill(Color.amber)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.amber.opacity(0.35), radius: 12, y: 4)
                Image(systemName: "mic.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("录音")
        .accessibilityHint("轻点开始录音")
    }
}

#Preview {
    RecordButton(action: {})
}
