import SwiftUI

/// Home-screen notice when the server can't be reached. Tapping opens 设置.
struct ServerStatusBanner: View {
    let message: String
    let onOpenSettings: () -> Void

    var body: some View {
        Button(action: onOpenSettings) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.red)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Can't reach the server")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    Text("Open Settings to check the address →")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accent)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Can't reach the server. Open Settings.")
    }
}
