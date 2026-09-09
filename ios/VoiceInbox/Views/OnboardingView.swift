import SwiftUI

/// First-run intro (PLAN-MVP.md #10): what the app does, where data goes,
/// and a primed microphone request — trust before the first tap.
struct OnboardingView: View {
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accent.opacity(0.18))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(Color.accent)
                    .frame(width: 92, height: 92)
                Image(systemName: "mic.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.onAccent)
            }
            .padding(.bottom, 28)

            Text("Voice Inbox")
                .font(.system(size: 30, weight: .bold))
            Text("Whatever comes to mind, just say it.")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 18) {
                OnboardingRow(
                    symbol: "waveform",
                    title: String(localized: "Speak to capture"),
                    detail: String(localized: "Tap the button and talk. Hold to keep recording, drag to the lock to go hands-free.")
                )
                OnboardingRow(
                    symbol: "sparkles",
                    title: String(localized: "AI sorts it out"),
                    detail: String(localized: "What you say becomes a to-do, a reminder, or an idea. You just confirm.")
                )
                OnboardingRow(
                    symbol: "lock.fill",
                    title: String(localized: "Your data stays with you"),
                    detail: String(localized: "Audio passes through the server only while being transcribed, then it's deleted. Results live only on this device.")
                )
            }
            .padding(.horizontal, 36)
            .padding(.top, 40)

            Spacer()

            Button(action: onDone) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(Color.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            Text("The first recording asks for microphone access")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
        .interactiveDismissDisabled()
    }
}

private struct OnboardingRow: View {
    var symbol: String
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    OnboardingView(onDone: {})
}
