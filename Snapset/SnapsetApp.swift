import SwiftUI
import SwiftData

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
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some View {
        TabView {
            Tab("Workout", systemImage: "figure.strengthtraining.traditional") {
                WorkoutView()
            }
            Tab("Routines", systemImage: "list.bullet.rectangle") {
                RoutineListView()
            }
            Tab("History", systemImage: "chart.line.uptrend.xyaxis") {
                HistoryView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { hasOnboarded = !$0 })) {
            OnboardingView()
        }
    }
}

#Preview {
    RootView().modelContainer(for: Exercise.self, inMemory: true)
}
