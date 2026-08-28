import Observation

/// Cross-entry-point signals (PLAN-MVP.md #8): the Start Capture intent bumps
/// `startToken`; the recorder control observes it and begins recording.
@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    /// Incremented whenever an external entry point asks to start recording.
    var startToken = 0

    private init() {}
}
