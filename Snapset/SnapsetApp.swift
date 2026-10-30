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
    var body: some View {
        TabView {
            Tab("Workout", systemImage: "figure.strengthtraining.traditional") {
                PlaceholderView(title: "Workout", message: "Start a session from a routine. Coming in Task 4.")
            }
            Tab("Routines", systemImage: "list.bullet.rectangle") {
                RoutineListView()
            }
            Tab("History", systemImage: "chart.line.uptrend.xyaxis") {
                PlaceholderView(title: "History", message: "Past sessions and maxes. Coming in Task 5.")
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

struct PlaceholderView: View {
    let title: String
    let message: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: "hammer", description: Text(message))
                .navigationTitle(title)
        }
    }
}

#Preview {
    RootView().modelContainer(for: Exercise.self, inMemory: true)
}
