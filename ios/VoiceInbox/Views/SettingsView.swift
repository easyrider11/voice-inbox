import SwiftUI

/// 设置 (PLAN-MVP.md #1): configurable server address with a connection test,
/// provider status, and the app's one-line privacy story.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ServerConfig.storageKey) private var serverURL = ServerConfig.fallback
    @AppStorage(RecognitionLanguage.storageKey) private var recognitionLanguage = RecognitionLanguage.system.rawValue

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
                    TextField("http://MacBook-Air-2.local:8787", text: $serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.callout.monospaced())
                    Button(action: testConnection) {
                        HStack {
                            Text("Test Connection")
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
                        LabeledContent("Speech Recognition", value: asr == "mock" ? String(localized: "On-device (Apple) — no cloud ASR on the server") : providerLabel(asr))
                        LabeledContent("Structuring", value: structurer == "mock" ? String(localized: "Rules (Claude not configured)") : providerLabel(structurer))
                    }
                    if case .failed(let message) = testState {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Server")
                } footer: {
                    Text("Phone and Mac must be on the same Wi-Fi. Simulator: 127.0.0.1; device: your Mac's Bonjour name or LAN address.")
                }

                Section {
                    Picker("Recognition Language", selection: $recognitionLanguage) {
                        ForEach(RecognitionLanguage.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                } header: {
                    Text("Speech")
                } footer: {
                    Text("Applies to both on-device recognition and the server. Chinese and English are both supported.")
                }

                Section {
                    Button("Reset to Default Address") {
                        serverURL = ServerConfig.fallback
                        testState = .idle
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    Text("Audio passes through your server only while being transcribed and is deleted right after. Results are stored only on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(.accent)
    }

    private func providerLabel(_ name: String) -> String {
        switch name {
        case "mock": String(localized: "Mock (no API key)")
        case "tencent": String(localized: "Tencent Cloud ASR")
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
                    testState = .failed(String(localized: "The address must start with http://"))
                    return
                }
                var request = URLRequest(url: base.appending(path: "health"))
                request.timeoutInterval = 5
                let (data, _) = try await URLSession.shared.data(for: request)
                let health = try JSONDecoder().decode(HealthResponse.self, from: data)
                testState = .ok(asr: health.providers.asr, structurer: health.providers.structurer)
            } catch {
                testState = .failed("Can't connect: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    SettingsView()
}
