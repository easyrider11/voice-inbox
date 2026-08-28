import Foundation
import SwiftData

// PROJECT.md §8 — client data model. SwiftData is the only long-term content store.

enum CaptureMode: String, Codable {
    case quick
    case meeting
}

enum CaptureStatus: String, Codable {
    case recording
    /// Audio captured locally; cloud pipeline (M2) hasn't picked it up yet.
    case recorded
    case uploading
    case processing
    case awaitingConfirm
    case saved
    case failed
}

@Model
final class CaptureRecord {
    var uuid: UUID
    var createdAt: Date
    var modeRaw: String
    var statusRaw: String
    /// Filename inside AudioStore's recordings directory (relative — container paths change between installs).
    var audioFilename: String?
    var durationSec: Double?
    var transcript: String?
    var language: String?
    /// Capture id on the backend, once the pipeline has started.
    var serverId: String?
    /// AI classification result (M2): intent + confidence + payload JSON from the server.
    var intentRaw: String?
    var confidence: Double?
    var payloadJSON: String?
    var lastError: String?

    var mode: CaptureMode {
        get { CaptureMode(rawValue: modeRaw) ?? .quick }
        set { modeRaw = newValue.rawValue }
    }

    var status: CaptureStatus {
        get { CaptureStatus(rawValue: statusRaw) ?? .failed }
        set { statusRaw = newValue.rawValue }
    }

    init(mode: CaptureMode, status: CaptureStatus = .recording, createdAt: Date = .now) {
        self.uuid = UUID()
        self.createdAt = createdAt
        self.modeRaw = mode.rawValue
        self.statusRaw = status.rawValue
    }
}

struct Subtask: Codable, Hashable {
    var text: String
    var done: Bool = false
}

@Model
final class TodoCard {
    var title: String
    var details: String
    var subtasks: [Subtask]
    var completedAt: Date?
    var createdAt: Date
    var sourceCaptureUUID: UUID?

    init(title: String, details: String = "", subtasks: [Subtask] = [], createdAt: Date = .now) {
        self.title = title
        self.details = details
        self.subtasks = subtasks
        self.createdAt = createdAt
    }
}

@Model
final class ReminderCard {
    var title: String
    var fireDate: Date
    var notificationID: String?
    var done: Bool
    var createdAt: Date
    var sourceCaptureUUID: UUID?

    init(title: String, fireDate: Date, done: Bool = false, createdAt: Date = .now) {
        self.title = title
        self.fireDate = fireDate
        self.done = done
        self.createdAt = createdAt
    }
}

@Model
final class IdeaCard {
    var title: String
    var bullets: [String]
    var createdAt: Date
    var sourceCaptureUUID: UUID?

    init(title: String, bullets: [String] = [], createdAt: Date = .now) {
        self.title = title
        self.bullets = bullets
        self.createdAt = createdAt
    }
}

struct MeetingSection: Codable, Hashable {
    var heading: String
    var points: [String]
}

@Model
final class MeetingNote {
    var title: String
    var duration: TimeInterval
    var summary: String
    var sections: [MeetingSection]
    var actionItems: [String]
    var audioKept: Bool
    var createdAt: Date
    var sourceCaptureUUID: UUID?

    init(title: String, duration: TimeInterval = 0, summary: String = "", createdAt: Date = .now) {
        self.title = title
        self.duration = duration
        self.summary = summary
        self.sections = []
        self.actionItems = []
        self.audioKept = false
        self.createdAt = createdAt
    }
}
