import ActivityKit
import AppIntents
import Foundation

/// The Live Activity shown in the Dynamic Island and on the Lock Screen while a workout runs.
/// Shared by the app (which starts and updates it) and the widget extension (which draws it).
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var times: WorkoutTimes
        var exercise: String     // e.g. "Chest Press"; empty when every planned set is logged
        var setLine: String      // e.g. "Set 2/4 · 60 kg × 8", or "All planned sets logged"
        var detail: String       // the two above in one line, for notifications
        var allSetsDone = false  // Finish saves at once; otherwise it opens the app to confirm

        var pausedAt: Date? { times.pausedAt }
    }

    var routineName: String
    var startedAt: Date
}

enum WorkoutButton: String, AppEnum {
    case pause, finish

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Workout button"
    static let caseDisplayRepresentations: [WorkoutButton: DisplayRepresentation] = [
        .pause: "Pause or resume", .finish: "Finish",
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

/// Finish from the Dynamic Island while planned sets are left: opens the app on the "Finish this workout?" alert
/// instead of ending it at once. With every set done, the island uses WorkoutButtonIntent(.finish), which saves in place.
struct ConfirmFinishIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Finish workout"
    static let isDiscoverable = false
    static let openAppWhenRun = true  // iOS 18 to 25; iOS 26 reads supportedModes
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground }

    /// Set by the app at launch: shows the finish alert on the Workout screen.
    @MainActor static var handler: (() -> Void)?

    init() {}

    @MainActor func perform() async throws -> some IntentResult {
        Self.handler?()
        return .result()
    }
}

/// Log set from the Dynamic Island: opens the app on the set confirm sheet, so nothing is saved until the lifter confirms.
struct LogSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Log set"
    static let isDiscoverable = false
    static let openAppWhenRun = true  // iOS 18 to 25; iOS 26 reads supportedModes
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground }

    /// Set by the app at launch: shows the set confirm sheet for the current exercise.
    @MainActor static var handler: (() -> Void)?

    init() {}

    @MainActor func perform() async throws -> some IntentResult {
        Self.handler?()
        return .result()
    }
}
