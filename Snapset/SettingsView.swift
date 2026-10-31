import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    @AppStorage("goal") private var goal: Goal = .muscle
    @AppStorage("experience") private var experience: Experience = .beginner
    @AppStorage("trainingDays") private var days = 3
    @AppStorage("saveToHealth") private var saveToHealth = true
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var exportFile: BackupFile?
    @State private var importing = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Weight unit", selection: $unit) {
                    ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                TrainingProfileSection(goal: $goal, experience: $experience, days: $days)

                Section {
                    Toggle("Save workouts to Health", isOn: $saveToHealth)
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Turn this off on days you also record the workout on your Apple Watch, so Fitness doesn't list it twice. Heart rate is read either way.")
                }

                Section {
                    Button("Export all data") {
                        do {
                            exportFile = BackupFile(data: try JSONEncoder().encode(Backup(context: context)))
                        } catch {
                            message = "Export failed: \(error.localizedDescription)"
                        }
                    }
                    Button("Import from file") { importing = true }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Saves your routines and workouts to one file in Files or iCloud Drive. Importing the same file again adds nothing new.")
                }

                Section("Exercise library") {
                    LabeledContent("Exercises", value: "\(exercises.count)")
                }
            }
            .navigationTitle("Settings")
            .fileExporter(isPresented: Binding(get: { exportFile != nil }, set: { if !$0 { exportFile = nil } }),
                          document: exportFile, contentType: .json,
                          defaultFilename: "Snapset \(Date.now.formatted(.iso8601.year().month().day()))") { result in
                if case .failure(let error) = result { message = "Export failed: \(error.localizedDescription)" }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    let added = try JSONDecoder().decode(Backup.self, from: Data(contentsOf: url)).restore(into: context)
                    message = added == 0 ? "Nothing new to import." : "Imported \(added) routines and workouts."
                } catch {
                    message = "Import failed: \(error.localizedDescription)"
                }
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") {}
            }
        }
    }
}

#Preview {
    SettingsView().modelContainer(for: Exercise.self, inMemory: true)
}
