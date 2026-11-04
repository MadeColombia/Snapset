import SwiftUI
import SwiftData
import SnapsetUI

@main
struct SnapsetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Exercise.self, Routine.self, RoutineItem.self, WorkoutSession.self, SetEntry.self)
            try Seed.exercises(into: container.mainContext)
        } catch {
            fatalError("Could not open the database: \(error)")
        }
        let context = container.mainContext
        WorkoutButtonIntent.handler = { WorkoutActivity.handle($0, in: context) }
        // Read by RootView (Workout tab) and SessionView (the sheet), also when this launch was the tap itself.
        LogSetIntent.handler = { UserDefaults.standard.set(true, forKey: "openLogSet") }
        ConfirmFinishIntent.handler = { UserDefaults.standard.set(true, forKey: "confirmFinish") }
        WorkoutIntentHandler.start = { SiriWorkout.start(named: $0, in: context) }
        WorkoutIntentHandler.pause = { SiriWorkout.setPaused($0, in: context) }
        WorkoutIntentHandler.end = { SiriWorkout.finish(in: context) }
        LiveMetrics.onChange = {
            guard let session = SiriWorkout.active(in: context) else { return }
            WorkoutActivity.refresh(session, in: context)
            if #available(iOS 26.0, *) {  // a workout begun while the last one was saving gets its own live session
                LiveWorkout.shared.follow(startedAt: session.startedAt, paused: session.pausedAt != nil)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

/// What Siri's workout intents do to the workout, the same as the buttons in the app.
@MainActor
enum SiriWorkout {
    static func active(in context: ModelContext) -> WorkoutSession? {
        var descriptor = FetchDescriptor(predicate: WorkoutSession.isActive, sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Starts the routine whose name Siri heard, ignoring case and accents. With no name, the app opens to pick one.
    static func start(named name: String?, in context: ModelContext) -> WorkoutIntentHandler.Outcome {
        guard active(in: context) == nil else { return .alreadyRunning }
        guard let name = name?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return .openApp }
        let routines = (try? context.fetch(FetchDescriptor<Routine>())) ?? []
        guard let routine = routines.first(where: { $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame })
        else { return .noMatch }
        let session = WorkoutSession(routine: routine)
        context.insert(session)
        try? context.save()
        WorkoutActivity.sync(session, in: context)
        return .done
    }

    static func setPaused(_ paused: Bool, in context: ModelContext) -> WorkoutIntentHandler.Outcome {
        guard let session = active(in: context) else { return .noWorkout }
        if (session.pausedAt != nil) != paused {
            session.togglePause()
            try? context.save()
        }
        WorkoutActivity.sync(session, in: context)
        return .done
    }

    static func finish(in context: ModelContext) -> WorkoutIntentHandler.Outcome {
        guard let session = active(in: context) else { return .noWorkout }
        session.finish(in: context)
        return .done
    }
}

struct RootView: View {
    enum AppTab { case workout, routines, progress, settings }

    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @AppStorage("openLogSet") private var openLogSet = false
    @AppStorage("confirmFinish") private var confirmFinish = false
    @Query(filter: WorkoutSession.isActive, sort: \WorkoutSession.startedAt, order: .reverse) private var active: [WorkoutSession]
    @State private var tab = AppTab.workout

    var body: some View {
        // The workout tab already shows the timer, so the bar only appears on the others.
        let bar = active.first.map { session in RunningWorkoutBar(session: session) { tab = .workout } }
        TabView(selection: $tab) {
            Tab("Workout", systemImage: "figure.strengthtraining.traditional", value: .workout) {
                WorkoutView()
            }
            Tab("Routines", systemImage: "list.bullet.rectangle", value: .routines) {
                RoutineListView().runningWorkoutInset(bar)
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis", value: .progress) {
                HistoryView().runningWorkoutInset(bar)
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView().runningWorkoutInset(bar)
            }
        }
        .runningWorkoutAccessory(tab == .workout ? nil : bar)
        .tint(Color.snap.textPrimary)  // orange is kept for each screen's one primary action
        .onChange(of: openLogSet, initial: true) { _, open in if open { tab = .workout } }
        .onChange(of: confirmFinish, initial: true) { _, open in if open { tab = .workout } }
        .fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { hasOnboarded = !$0 })) {
            OnboardingView().tint(Color.snap.textPrimary)
        }
    }
}

#Preview {
    RootView().modelContainer(for: Exercise.self, inMemory: true)
}
