import SwiftUI

/// 设置 (PLAN-MVP.md #1): configurable server address with a connection test,
/// provider status, and the app's one-line privacy story.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ServerConfig.storageKey) private var serverURL = ServerConfig.fallback

    private enum TestState: Equatable {
        case idle
        case testing
        case ok(asr: String, structurer: String)
        case failed(String)
    }

    @State private var testState: TestState = .idle

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://10.0.0.93:8787", text: $serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.callout.monospaced())
                    Button(action: testConnection) {
                        HStack {
                            Text("测试连接")
                            Spacer()
                            switch testState {
                            case .idle:
                                EmptyView()
                            case .testing:
                                ProgressView()
                            case .ok:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accent)
                            case .failed:
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .disabled(testState == .testing)
                    if case .ok(let asr, let structurer) = testState {
                        LabeledContent("语音识别", value: providerLabel(asr))
                        LabeledContent("整理模型", value: providerLabel(structurer))
                    }
                    if case .failed(let message) = testState {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("服务器")
                } footer: {
                    Text("手机与 Mac 需在同一 Wi-Fi。模拟器用 127.0.0.1，真机填 Mac 的局域网地址。")
                }

                Section {
                    Button("恢复默认地址") {
                        serverURL = ServerConfig.fallback
                        testState = .idle
                    }
                }

                Section("关于") {
                    LabeledContent("版本", value: "0.1.0 (M3)")
                    Text("录音只在处理期间经你的服务器转写，处理完即删；整理结果只保存在这台设备上。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(.accent)
    }

    private func providerLabel(_ name: String) -> String {
        switch name {
        case "mock": "模拟（未配置密钥）"
        case "tencent": "腾讯云 ASR"
        case "claude": "Claude"
        default: name
        }
    }

    private struct HealthResponse: Decodable {
        struct Providers: Decodable {
            let asr: String
            let structurer: String
        }
        let status: String
        let providers: Providers
    }

    private func testConnection() {
        testState = .testing
        let urlString = serverURL
        Task {
            do {
                guard let base = URL(string: urlString), base.scheme != nil else {
                    testState = .failed("地址格式不对，需要以 http:// 开头")
                    return
                }
                var request = URLRequest(url: base.appending(path: "health"))
                request.timeoutInterval = 5
                let (data, _) = try await URLSession.shared.data(for: request)
                let health = try JSONDecoder().decode(HealthResponse.self, from: data)
                testState = .ok(asr: health.providers.asr, structurer: health.providers.structurer)
            } catch {
                testState = .failed("连不上：\(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    SettingsView()
}
