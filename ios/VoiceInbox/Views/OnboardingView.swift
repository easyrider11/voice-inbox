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
                    .fill(Color.amber.opacity(0.18))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(Color.amber)
                    .frame(width: 92, height: 92)
                Image(systemName: "mic.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 28)

            Text("语音收件箱")
                .font(.system(size: 30, weight: .bold))
            Text("想到什么，说出来就行")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 18) {
                OnboardingRow(
                    symbol: "waveform",
                    title: "说话即记录",
                    detail: "轻点中间的按钮说一句，长按持续录，拖到锁图标免按住"
                )
                OnboardingRow(
                    symbol: "sparkles",
                    title: "AI 自动整理",
                    detail: "说的话自动分类成待办、提醒或想法，你只需确认"
                )
                OnboardingRow(
                    symbol: "lock.fill",
                    title: "数据留在你手里",
                    detail: "录音只在转写期间经过服务器，处理完即删；结果只存在这台设备上"
                )
            }
            .padding(.horizontal, 36)
            .padding(.top, 40)

            Spacer()

            Button(action: onDone) {
                Text("开始使用")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.amber)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            Text("首次录音时会请求麦克风权限")
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
                .foregroundStyle(Color.amber)
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
