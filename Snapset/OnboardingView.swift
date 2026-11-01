import SwiftUI
import SnapsetUI

enum Experience: String, CaseIterable {
    case beginner, intermediate, advanced

    var label: String { rawValue.capitalized }
}

/// Goal, experience and training days; shared by onboarding and Settings.
struct TrainingProfileSection: View {
    @Binding var goal: Goal
    @Binding var experience: Experience
    @Binding var days: Int

    var body: some View {
        Section {
            Picker("Goal", selection: $goal) {
                ForEach(Goal.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Picker("Experience", selection: $experience) {
                ForEach(Experience.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Stepper("\(days) days a week", value: $days, in: 1...7)
                .sensoryFeedback(Snap.Haptic.stepperChange, trigger: days)
        } header: {
            Text("Training")
        } footer: {
            Text("Snapset suggests weights and reps from the sets you log. It is not medical advice. If you have an injury or health condition, check with a professional first.")
        }
        .listRowBackground(Color.snap.surface)
    }
}

struct OnboardingView: View {
    @AppStorage("goal") private var savedGoal: Goal = .muscle
    @AppStorage("experience") private var savedExperience: Experience = .beginner
    @AppStorage("trainingDays") private var savedDays = 3
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    // Kept local until "Get started", so Skip leaves the defaults in place.
    @State private var goal = Goal.muscle
    @State private var experience = Experience.beginner
    @State private var days = 3

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Tell Snapset what you train for. It picks your rep ranges and when to add weight. You can change this later in Settings.")
                }
                .listRowBackground(Color.snap.surface)
                TrainingProfileSection(goal: $goal, experience: $experience, days: $days)
                Section {
                    PrimaryButton("Get started") {
                        savedGoal = goal
                        savedExperience = experience
                        savedDays = days
                        hasOnboarded = true
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .snapListBackground()
            .navigationTitle("Welcome")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { hasOnboarded = true }
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
}
