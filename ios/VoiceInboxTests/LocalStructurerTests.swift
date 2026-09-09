import Foundation
import Testing
@testable import VoiceInbox

struct LocalStructurerTests {
    let now = Date(timeIntervalSince1970: 1_788_600_000) // fixed reference instant
    let calendar = Calendar(identifier: .gregorian)

    @Test func reminderWithMinutes() {
        let out = LocalStructurer.structure("提醒我十分钟后喝水", now: now, calendar: calendar)
        #expect(out.intent == "reminder")
        #expect(out.payload.title == "十分钟后喝水")
        let fire = try? #require(out.payload.fireAt.flatMap { ISO8601DateFormatter().date(from: $0) })
        #expect(fire.map { abs($0.timeIntervalSince(now) - 600) < 1 } == true)
    }

    @Test func todoSplitsSubtasks() {
        let out = LocalStructurer.structure("今天要做三件事，第一发文档，第二写代码，第三健身", now: now, calendar: calendar)
        #expect(out.intent == "todo")
        #expect(out.payload.title == "今天要做三件事")
        #expect(out.payload.subtasks == ["发文档", "写代码", "健身"])
    }

    @Test func ideaStripsLeadIn() {
        let out = LocalStructurer.structure("我有个想法，做一个 MCP server，让别的工具也能写进来", now: now, calendar: calendar)
        #expect(out.intent == "idea")
        #expect(out.payload.title == "做一个 MCP server")
        #expect(out.payload.bullets == ["让别的工具也能写进来"])
    }

    @Test func tomorrowAfternoonResolvesToFifteen() throws {
        let out = LocalStructurer.structure("明天下午三点和设计师开会", now: now, calendar: calendar)
        #expect(out.intent == "reminder")
        let fire = try #require(out.payload.fireAt.flatMap { ISO8601DateFormatter().date(from: $0) })
        #expect(calendar.component(.hour, from: fire) == 15)
        #expect(fire > now)
    }

    @Test func unknownStaysUnclassified() {
        let out = LocalStructurer.structure("天气不错", now: now, calendar: calendar)
        #expect(out.intent == "unclassified")
    }
}
