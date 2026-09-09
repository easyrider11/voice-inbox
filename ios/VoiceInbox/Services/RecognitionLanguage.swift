import Foundation

/// Which language speech is recognized in — on-device (Apple locale) and on
/// the server (engine choice). Chinese and English are both first-class;
/// "system" follows the phone's language.
enum RecognitionLanguage: String, CaseIterable, Identifiable {
    case system
    case chinese
    case english

    static let storageKey = "recognitionLanguage"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "Follow system")
        case .chinese: "中文"
        case .english: "English"
        }
    }

    static var current: RecognitionLanguage {
        RecognitionLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    var resolved: RecognitionLanguage {
        guard self == .system else { return self }
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return code.hasPrefix("zh") ? .chinese : .english
    }

    /// Apple Speech locale.
    var locale: Locale {
        resolved == .chinese ? Locale(identifier: "zh-CN") : Locale(identifier: "en-US")
    }

    /// Short hint sent to the server so it can pick the ASR engine.
    var hint: String {
        resolved == .chinese ? "zh" : "en"
    }
}
