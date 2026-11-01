import SwiftUI
import SnapsetUI
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
                .listRowBackground(Color.snap.surface)

                TrainingProfileSection(goal: $goal, experience: $experience, days: $days)

                Section {
                    Toggle("Save workouts to Health", isOn: $saveToHealth)
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Turn this off on days you also record the workout on your Apple Watch, so Fitness doesn't list it twice. Heart rate is read either way.")
                }
                .listRowBackground(Color.snap.surface)

                Section {
                    Button("Export all data") {
                        do {
                            exportFile = BackupFile(data: try JSONEncoder().encode(Backup(context: context)))
                        } catch {
                            message = "Couldn't export your data. Try again. (\(error.localizedDescription))"
                        }
                    }
                    Button("Import from file") { importing = true }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Saves your routines and workouts to one file in Files or iCloud Drive. Importing the same file again adds nothing new.")
                }
                .listRowBackground(Color.snap.surface)

                Section {
                    LabeledContent("Exercises", value: "\(exercises.count)")
                } header: {
                    Text("Exercise library")
                } footer: {
                    // CC BY-SA 4.0 requires naming the author, the license and that the images were resized.
                    Text("Exercise drawings by [Everkinetic](https://github.com/everkinetic/data), licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Resized for the app.")
                }
                .listRowBackground(Color.snap.surface)
            }
            .snapListBackground()
            .navigationTitle("Settings")
            .fileExporter(isPresented: Binding(get: { exportFile != nil }, set: { if !$0 { exportFile = nil } }),
                          document: exportFile, contentType: .json,
                          defaultFilename: "Snapset \(Date.now.formatted(.iso8601.year().month().day()))") { result in
                if case .failure(let error) = result { message = "Couldn't save the export. Try again. (\(error.localizedDescription))" }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    let added = try JSONDecoder().decode(Backup.self, from: Data(contentsOf: url)).restore(into: context)
                    message = added == 0 ? "Nothing new to import." : "Imported \(added) routines and workouts."
                } catch {
                    message = "Couldn't import that file. Check it's a Snapset backup and try again. (\(error.localizedDescription))"
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
