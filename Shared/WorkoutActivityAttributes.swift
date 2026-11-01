import ActivityKit
import AppIntents
import Foundation

/// The Live Activity shown in the Dynamic Island and on the Lock Screen while a workout runs.
/// Shared by the app (which starts and updates it) and the widget extension (which draws it).
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var pausedAt: Date?
        var pausedSeconds: Double = 0
        var detail: String       // e.g. "Set 2/3: 60 kg × 8 · Bench Press"
        var canLogSet: Bool
    }

    var routineName: String
    var startedAt: Date
}

enum WorkoutButton: String, AppEnum {
    case pause, finish, logSet

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Workout button"
    static let caseDisplayRepresentations: [WorkoutButton: DisplayRepresentation] = [
        .pause: "Pause or resume", .finish: "Finish", .logSet: "Log set",
    ]
}

/// The expanded Dynamic Island's buttons. They run in the app's process, which sets `handler` at launch;
/// the widget extension only needs the type to draw them.
struct WorkoutButtonIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Workout button"
    static let isDiscoverable = false

    @MainActor static var handler: ((WorkoutButton) -> Void)?

    @Parameter(title: "Button") var button: WorkoutButton

    init() {}
    init(_ button: WorkoutButton) { self.button = button }

    @MainActor func perform() async throws -> some IntentResult {
        Self.handler?(button)
        return .result()
    }
}
