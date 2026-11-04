import HealthKitUI  // UIScene.ConnectionOptions.shouldHandleActiveWorkoutRecovery lives here, not in UIKit
import Intents
import UIKit

/// Siri's workout intents: "Start Push Day in Snapset", pause, resume and finish. On iOS 26 the Lock Screen's workout
/// controls use them too, which is why they are handled inside the app, not in an Intents extension.
final class WorkoutIntentHandler: NSObject, INStartWorkoutIntentHandling, INPauseWorkoutIntentHandling,
                                  INResumeWorkoutIntentHandling, INEndWorkoutIntentHandling {
    enum Outcome { case done, noWorkout, alreadyRunning, noMatch, openApp }

    /// Set by the app at launch, like the Live Activity buttons. `start` gets the routine name Siri heard, if any.
    @MainActor static var start: ((String?) -> Outcome)?
    /// True pauses, false resumes.
    @MainActor static var pause: ((Bool) -> Outcome)?
    @MainActor static var end: (() -> Outcome)?

    func handle(intent: INStartWorkoutIntent) async -> INStartWorkoutIntentResponse {
        let name = intent.workoutName?.spokenPhrase
        let outcome = await MainActor.run { Self.start?(name) } ?? .openApp
        let code: INStartWorkoutIntentResponseCode = switch outcome {
        case .done: .success
        case .alreadyRunning: .failureOngoingWorkout
        case .noMatch: .failureNoMatchingWorkout
        case .noWorkout, .openApp: .continueInApp  // no name heard: the routine is picked in the app
        }
        return INStartWorkoutIntentResponse(code: code, userActivity: nil)
    }

    func handle(intent: INPauseWorkoutIntent) async -> INPauseWorkoutIntentResponse {
        let outcome = await MainActor.run { Self.pause?(true) } ?? .openApp
        return INPauseWorkoutIntentResponse(code: outcome == .done ? .success : .failureNoMatchingWorkout, userActivity: nil)
    }

    func handle(intent: INResumeWorkoutIntent) async -> INResumeWorkoutIntentResponse {
        let outcome = await MainActor.run { Self.pause?(false) } ?? .openApp
        return INResumeWorkoutIntentResponse(code: outcome == .done ? .success : .failureNoMatchingWorkout, userActivity: nil)
    }

    func handle(intent: INEndWorkoutIntent) async -> INEndWorkoutIntentResponse {
        let outcome = await MainActor.run { Self.end?() } ?? .openApp
        return INEndWorkoutIntentResponse(code: outcome == .done ? .success : .failureNoMatchingWorkout, userActivity: nil)
    }
}

/// Hands Siri's workout intents to the handler, and on iOS 26 picks up a workout session that a crash interrupted.
final class AppDelegate: NSObject, UIApplicationDelegate {
    private let intents = WorkoutIntentHandler()

    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        intents
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if #available(iOS 26.0, *), options.shouldHandleActiveWorkoutRecovery {
            Task { await LiveWorkout.shared.recover() }
        }
        // As in Apple's iPhone workout sample: SwiftUI still draws the window; this delegate only has to exist.
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {}
