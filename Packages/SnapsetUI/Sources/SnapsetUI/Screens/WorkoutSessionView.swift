import SwiftUI

/// S12: the running workout as a vertical roadmap, with logging in thumb reach.
struct WorkoutSessionView: View {
    struct Step: Identifiable {
        enum State { case done, current, upcoming }
        var id: String { name }
        var name: String
        var state: State
        var summary: String
    }

    struct Current {
        var weight: String
        var reps: String
        var sets: Int
        var status: StatusBadge.Status?
        var reason: String
        var isFirstTime = false
        var logged: [(weight: Double, reps: Int, warmUp: Bool)] = []
        var restRemaining: TimeInterval?
        var next: String?
    }

    struct Model {
        var routine: String
        var elapsed: String
        var steps: [Step]
        var current: Current
    }

    let model: Model

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Snap.Spacing.s) {
                    ForEach(model.steps) { step in
                        switch step.state {
                        case .done: doneRow(step)
                        case .current: currentCard(step)
                        case .upcoming: upcomingRow(step)
                        }
                    }
                }
                .padding(Snap.Spacing.l)
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .background(Color.snap.background)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Snap.Spacing.xs) {
                Text(model.routine).snapText(.sectionTitle).foregroundStyle(Color.snap.textPrimary)
                Text(model.elapsed).snapText(.secondary).monospacedDigit()
            }
            Spacer()
            Button("Finish") { }
                .font(.headline)
                .foregroundStyle(Color.snap.textPrimary)
                .frame(minWidth: Snap.Tap.min, minHeight: Snap.Tap.min)
        }
        .padding(.horizontal, Snap.Spacing.l)
        .padding(.vertical, Snap.Spacing.s)
    }

    private func doneRow(_ step: Step) -> some View {
        HStack(spacing: Snap.Spacing.m) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.snap.statusUp)
                .accessibilityLabel("Done")
            Text(step.name).foregroundStyle(Color.snap.textPrimary)
            Spacer(minLength: 0)
            Text(step.summary).snapText(.secondary).monospacedDigit()
        }
        .snapText(.body)
        .frame(minHeight: Snap.Tap.min)
        .accessibilityElement(children: .combine)
    }

    private func upcomingRow(_ step: Step) -> some View {
        HStack(spacing: Snap.Spacing.m) {
            Image(systemName: "circle").accessibilityHidden(true)
            Text(step.name)
            Spacer(minLength: 0)
            Text(step.summary).monospacedDigit()
        }
        .snapText(.body)
        .foregroundStyle(Color.snap.textSecondary)
        .frame(minHeight: Snap.Tap.min)
        .accessibilityElement(children: .combine)
    }

    private func currentCard(_ step: Step) -> some View {
        let current = model.current
        return VStack(alignment: .leading, spacing: Snap.Spacing.m) {
            Text(step.name).snapText(.sectionTitle)
            HStack(alignment: .firstTextBaseline, spacing: Snap.Spacing.s) {
                Text(current.weight).snapText(.heroNumber).lineLimit(1).minimumScaleFactor(0.5)
                Text("kg × \(current.reps)").snapText(.heroUnit)
            }
            .accessibilityElement(children: .combine)
            Text("\(current.sets) sets").snapText(.secondary)
            if current.isFirstTime {
                Banner(.sky, systemImage: "play.circle", "First time? Watch the loop, then go light.")
            } else if let status = current.status {
                HStack(alignment: .firstTextBaseline, spacing: Snap.Spacing.s) {
                    StatusBadge(status)
                    Text(current.reason).snapText(.secondary)
                }
            }
            if !current.logged.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(current.logged.enumerated()), id: \.offset) { index, set in
                        SetRow(number: index + 1, weight: set.weight, reps: set.reps, isWarmUp: set.warmUp)
                    }
                }
            }
            if let rest = current.restRemaining {
                // Surface panel so the timer's surfaceRaised buttons stand out from the card.
                RestTimer(remaining: rest, onSkip: {}, onAddThirty: {})
                    .padding(Snap.Spacing.m)
                    .background(Color.snap.surface, in: .rect(cornerRadius: Snap.Radius.control))
                if let next = current.next {
                    Text("Next: \(next)").snapText(.secondary)
                }
            }
        }
        .foregroundStyle(Color.snap.textPrimary)
        .padding(Snap.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.snap.surfaceRaised, in: .rect(cornerRadius: Snap.Radius.card))
        .overlay(alignment: .leading) {
            Capsule().fill(Color.snap.textPrimary).frame(width: 4).padding(.vertical, Snap.Spacing.l)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: Snap.Spacing.m) {
            PrimaryButton("Log set") { }
            SecondaryButton("Log set from photo", systemImage: "camera", iconOnly: true) { }
        }
        .padding(.horizontal, Snap.Spacing.l)
        .padding(.vertical, Snap.Spacing.s)
        .background(Color.snap.background)
    }
}

extension WorkoutSessionView.Model {
    private static let steps: [WorkoutSessionView.Step] = [
        .init(name: "Leg press", state: .done, summary: "3 × 12"),
        .init(name: "Chest press", state: .done, summary: "3 × 10"),
        .init(name: "Seated row", state: .current, summary: ""),
        .init(name: "Lat pulldown", state: .upcoming, summary: "3 sets"),
        .init(name: "Shoulder press", state: .upcoming, summary: "3 sets"),
    ]

    static let midSession = Self(
        routine: "Upper and lower A", elapsed: "32:14", steps: steps,
        current: .init(weight: "42.5", reps: "8 to 12", sets: 3, status: .up,
                       reason: "You got 12 on every set last time. Add 2.5 kg.",
                       logged: [(20, 10, true), (42.5, 12, false)]))

    static let firstTime = Self(
        routine: "Upper and lower A", elapsed: "32:14", steps: steps,
        current: .init(weight: "20", reps: "8 to 12", sets: 3, status: nil, reason: "", isFirstTime: true))

    static let resting = Self(
        routine: "Upper and lower A", elapsed: "34:02", steps: steps,
        current: .init(weight: "42.5", reps: "8 to 12", sets: 3, status: .up,
                       reason: "You got 12 on every set last time. Add 2.5 kg.",
                       logged: [(42.5, 12, false)], restRemaining: 84, next: "42.5 kg × 10"))
}

#Preview("Mid-session, dark") { WorkoutSessionView(model: .midSession).preferredColorScheme(.dark) }
#Preview("Mid-session, light") { WorkoutSessionView(model: .midSession).preferredColorScheme(.light) }
#Preview("First time") { WorkoutSessionView(model: .firstTime).preferredColorScheme(.dark) }
#Preview("Resting") { WorkoutSessionView(model: .resting).preferredColorScheme(.dark) }
#Preview("Mid-session, AX5") {
    WorkoutSessionView(model: .midSession).preferredColorScheme(.dark).dynamicTypeSize(.accessibility5)
}
