import SwiftUI
import SwiftData
import SnapsetUI

@main
struct SnapsetApp: App {
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
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    enum AppTab { case workout, routines, progress, settings }

    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @AppStorage("openLogSet") private var openLogSet = false
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
        .fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { hasOnboarded = !$0 })) {
            OnboardingView().tint(Color.snap.textPrimary)
        }
    }
}

#Preview {
    RootView().modelContainer(for: Exercise.self, inMemory: true)
}
