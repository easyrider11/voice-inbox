import Foundation

/// On-device structuring — a Swift port of the server's rule-based structurer,
/// so the app still turns speech into cards with no server reachable at all
/// (offline use, and App Review, which cannot see a private Mac). When the
/// server is reachable, its structurer (Claude when configured) takes over.
enum LocalStructurer {
    struct Output {
        let intent: String
        let confidence: Double
        let payload: CaptureAPI.Payload
    }

    static func structure(_ transcript: String, now: Date = .now, calendar: Calendar = .current) -> Output {
        let parts = clauses(transcript)
        let first = parts.first ?? transcript

        func reminder() -> Output {
            let title = first.replacingOccurrences(of: #"^提醒我?"#, with: "", options: .regularExpression)
            return Output(
                intent: "reminder",
                confidence: 0.8,
                payload: CaptureAPI.Payload(title: title.isEmpty ? first : title, fireAt: guessFireAt(transcript, now: now, calendar: calendar))
            )
        }

        if matches(transcript, #"提醒|remind"#) {
            return reminder()
        }

        if matches(transcript, #"想法|idea|可以做|不如"#) {
            var bullets = Array(parts.dropFirst())
            var title = first.replacingOccurrences(of: #"^我有个想法[，,]?"#, with: "", options: .regularExpression)
            if title.isEmpty {
                title = bullets.first ?? "一个想法"
                bullets = Array(bullets.dropFirst())
            }
            return Output(intent: "idea", confidence: 0.75, payload: CaptureAPI.Payload(title: title, bullets: bullets))
        }

        if matches(transcript, #"要做|第一|然后|先|再"#) {
            let subtasks = parts.dropFirst()
                .map { $0.replacingOccurrences(of: #"^第[一二三四五六七八九十]"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return Output(
                intent: "todo",
                confidence: 0.8,
                payload: CaptureAPI.Payload(title: first.isEmpty ? "今天的事" : first, details: "", subtasks: Array(subtasks))
            )
        }

        if matches(transcript, #"[两一二三四五六七八九十0-9]点"#), matches(transcript, #"明天|后天|早上|上午|下午|晚上"#) {
            return reminder()
        }

        return Output(intent: "unclassified", confidence: 0.4, payload: CaptureAPI.Payload(title: first))
    }

    // MARK: - Helpers (mirror server/src/providers/structurer-mock.ts)

    private static let numerals: [Character: Int] = [
        "一": 1, "两": 2, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9, "十": 10,
    ]

    static func clauses(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: "，,。；;\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func number(from token: Substring) -> Int? {
        if let n = Int(token) { return n }
        if token.count == 1, let c = token.first, let n = numerals[c] { return n }
        return nil
    }

    /// "十分钟后" → now + 10 min; "明天下午三点" → tomorrow 15:00. ISO-8601 string.
    static func guessFireAt(_ transcript: String, now: Date, calendar: Calendar) -> String? {
        let iso = ISO8601DateFormatter()
        if let m = transcript.range(of: #"([一二三四五六七八九十两0-9]+)分钟后"#, options: .regularExpression) {
            let token = transcript[m].dropLast(3)
            if let minutes = number(from: token) {
                return iso.string(from: now.addingTimeInterval(TimeInterval(minutes * 60)))
            }
        }
        guard let m = transcript.range(of: #"([一二三四五六七八九十两0-9]+)点"#, options: .regularExpression),
              var hour = number(from: transcript[m].dropLast(1)) else { return nil }
        if matches(transcript, #"下午|晚上"#), hour < 12 { hour += 12 }
        var fire = now
        if transcript.contains("明天"), let t = calendar.date(byAdding: .day, value: 1, to: fire) { fire = t }
        guard var dated = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: fire) else { return nil }
        if dated <= now, let t = calendar.date(byAdding: .day, value: 1, to: dated) { dated = t }
        return iso.string(from: dated)
    }
}
