import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Snapset
import SnapsetUI

/// Renders each screen with sample data to PNGs in design/previews/, for design review.
/// Off by default. Run it on its own, since spinning the run loop can fire other suites' SwiftData timers:
/// TEST_RUNNER_SNAPSHOTS=1 xcodebuild test -only-testing:SnapsetTests/ScreenSnapshotTests ...
/// It checks only that a render was written.
@MainActor
struct ScreenSnapshotTests {
    let container: ModelContainer  // must outlive the context, or SwiftData traps
    let context: ModelContext
    let session: WorkoutSession
    let legs: Exercise
    let press: Exercise
    let routine: Routine

    init() throws {
        container = try ModelContainer(
            for: Exercise.self, Routine.self, RoutineItem.self, WorkoutSession.self, SetEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
        try Seed.exercises(into: context)
        let byID = Dictionary(try context.fetch(FetchDescriptor<Exercise>()).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        press = byID["machine.chest-press"]!
        let row = byID["machine.seated-row"]!
        legs = byID["machine.leg-press"]!

        routine = Routine(name: "Upper and lower A")
        context.insert(routine)
        for (order, exercise) in [legs, press, row].enumerated() {
            routine.items.append(RoutineItem(order: order, exercise: exercise))
        }
        context.insert(Routine(name: "Pull day"))

        // Three past weeks: the press hit the top of the range, so its target goes up.
        for week in (1...3).reversed() {
            let day = Date.now.addingTimeInterval(Double(-week * 7) * 86_400)
            let past = WorkoutSession(routine: routine)
            past.startedAt = day
            context.insert(past)
            for exercise in [legs, press, row] {
                for set in 0..<3 {
                    let kg = exercise === press ? 40 + Double(3 - week) * 2.5 : exercise === legs ? 100 : 42.5
                    past.sets.append(SetEntry(exercise: exercise, weightKg: kg, reps: exercise === row && set == 2 ? 9 : 12,
                                              loggedAt: day.addingTimeInterval(Double(set) * 120)))
                }
            }
            past.finishedAt = day.addingTimeInterval(3_600)
        }

        // One open session, stepped through the workout states as the screens render (a second open one would count as history).
        session = WorkoutSession(routine: routine)
        session.startedAt = .now.addingTimeInterval(-1_934)
        context.insert(session)
        try context.save()
        UserDefaults.standard.set("kg", forKey: "weightUnit")
        UserDefaults.standard.set("muscle", forKey: "goal")
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["SNAPSHOTS"] != nil))
    func renderScreens() throws {
        let workout = { (legSets: Int, pressSets: Int, resting: Bool, paused: Bool) -> AnyView in
            session.pausedAt = paused ? .now : nil
            session.sets.forEach(context.delete)
            session.sets = (0..<legSets).map { SetEntry(exercise: legs, weightKg: 100, reps: 12, loggedAt: .now.addingTimeInterval(Double($0 - 4) * 150)) }
                + (0..<pressSets).map { _ in SetEntry(exercise: press, weightKg: 47.5, reps: 12) }
            try? context.save()
            return AnyView(NavigationStack { SessionView(session: session, restingUntil: resting ? .now.addingTimeInterval(75) : nil) { _, _ in } })
        }
        let screens: [(String, () -> AnyView)] = [
            ("start-workout", { AnyView(NavigationStack { StartWorkoutView() }) }),
            ("countdown", { AnyView(CountdownView(onFinish: {}, onCancel: {})) }),
            ("workout-first-set", { workout(0, 0, false, false) }),
            ("workout-exercise-done", { workout(3, 0, false, false) }),
            ("workout-rest-paused", { workout(3, 1, true, true) }),
            ("workout-rest", { workout(3, 1, true, false) }),  // leaves the session mid-workout for the screens below
            ("set-confirm", { AnyView(SetConfirmView(exercise: press, targetKg: 50, targetReps: 8) { _, _ in }) }),
            ("set-edit", { AnyView(SetConfirmView(exercise: press, editing: session.sets.first { $0.exercise === press }, onDelete: {}) { _, _ in }) }),
            ("running-bar", { AnyView(VStack { Spacer(); RunningWorkoutBar(session: session) {} }.background(Color.snap.background)) }),
            ("routines", { AnyView(RoutineListView()) }),
            ("routine-editor", { AnyView(NavigationStack { RoutineEditorView(routine: routine) }) }),
            ("progress", { AnyView(HistoryView()) }),
            ("exercise-detail", { AnyView(NavigationStack { ExerciseDetailView(exercise: press) }) }),
            ("onboarding", { AnyView(OnboardingView()) }),
            ("settings", { AnyView(SettingsView()) }),
        ]
        let dir = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "design/previews")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (name, make) in screens {
            let view = make()
            for variant in ["dark", "light", "ax5"] {
                let themed = view
                    .tint(Color.snap.textPrimary)
                    .dynamicTypeSize(variant == "ax5" ? .accessibility5 : .large)
                    .modelContainer(container)
                let data = try #require(render(AnyView(themed), style: variant == "light" ? .light : .dark))
                try data.write(to: dir.appending(path: "app-\(name)-\(variant).png"))
            }
        }
    }

    private func render(_ view: AnyView, style: UIUserInterfaceStyle) -> Data? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return nil }
        let window = UIWindow(windowScene: scene)
        window.frame = scene.screen.bounds
        window.overrideUserInterfaceStyle = style
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        RunLoop.main.run(until: .now.addingTimeInterval(1))  // let .task pre-fills and queries settle
        defer { window.isHidden = true }
        return UIGraphicsImageRenderer(bounds: window.bounds).pngData { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }
}
