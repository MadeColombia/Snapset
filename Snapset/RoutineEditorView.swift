import SwiftUI
import SwiftData

struct RoutineEditorView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("goal") private var goal: Goal = .muscle
    @Bindable var routine: Routine
    @State private var showingPicker = false

    private var items: [RoutineItem] { routine.items.sorted { $0.order < $1.order } }

    var body: some View {
        List {
            Section("Name") {
                TextField("Routine name", text: $routine.name)
            }
            Section {
                ForEach(items) { item in
                    let reps = item.targetReps.map { "\($0) reps" }
                        ?? "\(goal.repRange.lowerBound)–\(goal.repRange.upperBound) reps"
                    DisclosureGroup {
                        Stepper("\(item.targetSets) sets", value: Bindable(item).targetSets, in: 1...10)
                        // Below 1 goes back to following the goal's range.
                        Stepper {
                            Text(item.targetReps == nil ? "Goal range · \(reps)" : reps)
                        } onIncrement: {
                            item.targetReps = min(30, item.targetReps.map { $0 + 1 } ?? goal.repRange.lowerBound)
                        } onDecrement: {
                            item.targetReps = item.targetReps.flatMap { $0 > 1 ? $0 - 1 : nil }
                        }
                        if item.targetReps != nil {
                            Button("Use goal range") { item.targetReps = nil }
                        }
                    } label: {
                        HStack {
                            if let exercise = item.exercise { ExerciseThumbnail(exercise: exercise) }
                            VStack(alignment: .leading) {
                                Text(item.exercise?.name ?? "Unknown exercise")
                                Text("\(item.targetSets) sets · \(reps)").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onMove(perform: move)
                .onDelete(perform: remove)

                Button("Add exercise", systemImage: "plus.circle.fill") { showingPicker = true }
            } header: {
                Text("Exercises")
            } footer: {
                Text("Goal range follows your goal in Settings (\(goal.label): \(goal.repRange.lowerBound)–\(goal.repRange.upperBound) reps). Set a number to use fixed reps for an exercise.")
            }
        }
        .navigationTitle(routine.name.isEmpty ? "Routine" : routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(isPresented: $showingPicker) {
            ExercisePickerView { exercise in
                routine.items.append(RoutineItem(order: (items.last?.order ?? -1) + 1, exercise: exercise))
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = items
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in reordered.enumerated() { item.order = index }
    }

    private func remove(at offsets: IndexSet) {
        let removed = offsets.map { items[$0] }
        routine.items.removeAll { removed.contains($0) }
        removed.forEach(context.delete)
    }
}

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var search = ""
    let onPick: (Exercise) -> Void

    private var filtered: [Exercise] {
        search.isEmpty ? exercises : exercises.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { exercise in
                Button {
                    onPick(exercise)
                    dismiss()
                } label: {
                    HStack {
                        ExerciseThumbnail(exercise: exercise)
                        VStack(alignment: .leading) {
                            Text(exercise.name).foregroundStyle(.primary)
                            Text(exercise.equipment.label).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)
            }
            .overlay {
                if filtered.isEmpty { ContentUnavailableView.search(text: search) }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
