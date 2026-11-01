import SwiftUI
import SwiftData
import SnapsetUI

struct RoutineListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @State private var path: [Routine] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(routines) { routine in
                    NavigationLink(value: routine) {
                        VStack(alignment: .leading, spacing: Snap.Spacing.xs) {
                            Text(routine.name.isEmpty ? "Untitled routine" : routine.name).snapText(.sectionTitle)
                            Text("^[\(routine.items.count) exercise](inflect: true)").snapText(.secondary)
                        }
                        .frame(minHeight: Snap.Tap.min, alignment: .leading)
                    }
                }
                .onDelete { offsets in
                    offsets.map { routines[$0] }.forEach(context.delete)
                }
                .listRowBackground(Color.snap.surface)
            }
            .snapListBackground()
            .overlay {
                if routines.isEmpty {
                    ContentUnavailableView {
                        Label("No routines", systemImage: "list.bullet.rectangle")
                    } description: {
                        Text("Create a routine to plan the exercises for a workout day.")
                    } actions: {
                        PrimaryButton("New routine", action: addRoutine).padding(.horizontal, Snap.Spacing.xl)
                    }
                }
            }
            .navigationTitle("Routines")
            .navigationDestination(for: Routine.self) { RoutineEditorView(routine: $0) }
            .onChange(of: path) { old, new in
                // A routine left with no exercises can't be started, so going back throws it away.
                for routine in old where !new.contains(routine) && routine.items.isEmpty {
                    context.delete(routine)
                }
            }
            .toolbar {
                Button("New routine", systemImage: "plus", action: addRoutine)
            }
        }
    }

    private func addRoutine() {
        let routine = Routine(name: "New routine")
        context.insert(routine)
        path.append(routine)
    }
}

#Preview {
    RoutineListView().modelContainer(for: Routine.self, inMemory: true)
}
