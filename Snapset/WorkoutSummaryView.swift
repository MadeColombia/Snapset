import Charts
import SwiftUI
import SnapsetUI

/// The overview after Finish: the headline numbers, heart rate from Apple Health when there is any,
/// today's top weights against last time, new bests and what goes up next time.
struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    /// Readings to show without asking Health, for previews and snapshots; nil loads them.
    var heartRate: [HeartRatePoint]?
    let onDone: () -> Void

    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    @State private var loaded: [HeartRatePoint]?
    @State private var cheered = false

    private var readings: [HeartRatePoint]? { heartRate ?? loaded }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Snap.Spacing.l) {
                header
                stats
                heartRateCard
                comparisonCard
                if !summary.newBests.isEmpty { newBestsCard }
                nextTimeCard
                exercisesCard
            }
            .padding(Snap.Spacing.l)
        }
        .background(Color.snap.background)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton("Done", style: .neutral, action: onDone)
                .padding(.horizontal, Snap.Spacing.l)
                .padding(.vertical, Snap.Spacing.s)
                .background(Color.snap.background)
        }
        .task {
            guard heartRate == nil else { return }
            let window = summary.heartRateWindow
            var samples = await Health.heartRateSamples(from: window.lowerBound, to: window.upperBound)
            if samples.isEmpty {
                // A Watch can take a few seconds to hand its last readings to the phone.
                try? await Task.sleep(for: .seconds(10))
                samples = await Health.heartRateSamples(from: window.lowerBound, to: window.upperBound)
            }
            withAnimation(Snap.Motion.standard) { loaded = samples }
        }
        .onAppear { cheered = !summary.newBests.isEmpty }
        .sensoryFeedback(Snap.Haptic.newBest, trigger: cheered) { _, new in new }
    }

    // MARK: Header and numbers

    private var header: some View {
        VStack(alignment: .leading, spacing: Snap.Spacing.xs) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.snap.statusUp)
                .accessibilityHidden(true)
            Text("Workout done").snapText(.screenTitle).foregroundStyle(Color.snap.textPrimary)
            Text([summary.routineName, summary.finishedAt.formatted(.dateTime.weekday(.wide).day().month())]
                .compactMap { $0 }.joined(separator: " · "))
                .snapText(.secondary)
            Text(headline).snapText(.body).foregroundStyle(Color.snap.textPrimary).padding(.top, Snap.Spacing.s)
        }
    }

    /// The spotter's one line about the session.
    private var headline: String {
        if let best = summary.newBests.first {
            let others = summary.newBests.count - 1
            return "You lifted more than ever on \(best.name.lowercased())" + (others > 0 ? " and \(others) more." : ".")
        }
        if !summary.goingUp.isEmpty {
            let count = summary.goingUp.count
            return "You earned heavier weights next time on \(count) \(count == 1 ? "exercise" : "exercises")."
        }
        return "Solid work. Same weights next time, try for one more rep."
    }

    private var stats: some View {
        let columns = [GridItem(.adaptive(minimum: 150), spacing: Snap.Spacing.s)]
        return LazyVGrid(columns: columns, spacing: Snap.Spacing.s) {
            StatTile(value: Duration.seconds(summary.activeSeconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)),
                     label: "Workout time", symbol: "stopwatch")
            StatTile(value: summary.setsPlanned > 0 ? "\(summary.setsLogged) of \(summary.setsPlanned)" : "\(summary.setsLogged)",
                     label: "Sets", symbol: "square.stack.3d.up")
            StatTile(value: "\(summary.exercises.count)", label: summary.exercises.count == 1 ? "Exercise" : "Exercises", symbol: "dumbbell")
            if let stats = heartRateStats {
                StatTile(value: "\(Int(stats.average.rounded())) bpm", label: "Average heart rate", symbol: "heart")
            } else {
                StatTile(value: "\(summary.newBests.count)", label: summary.newBests.count == 1 ? "New best" : "New bests", symbol: "trophy")
            }
        }
    }

    // MARK: Heart rate

    private var heartRateStats: (average: Double, max: Double, min: Double)? {
        guard let readings, !readings.isEmpty else { return nil }
        let values = readings.map(\.bpm)
        return (values.reduce(0, +) / Double(values.count), values.max()!, values.min()!)
    }

    @ViewBuilder
    private var heartRateCard: some View {
        if let readings, let stats = heartRateStats, readings.count > 1 {
            Card("Heart rate") {
                Chart {
                    ForEach(Array(summary.setTimes.enumerated()), id: \.offset) { _, time in
                        RuleMark(x: .value("Set", time))
                            .foregroundStyle(Color.snap.line)
                            .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                    ForEach(readings, id: \.self) { point in
                        AreaMark(x: .value("Time", point.date),
                                 yStart: .value("Floor", stats.min - 10),
                                 yEnd: .value("Heart rate", point.bpm))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [Color.snap.accent.opacity(0.35), Color.snap.accent.opacity(0)],
                                                             startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Time", point.date), y: .value("Heart rate", point.bpm))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.snap.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                    RuleMark(y: .value("Average", stats.average))
                        .foregroundStyle(Color.snap.textSecondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .chartYScale(domain: (stats.min - 10)...(stats.max + 10))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .frame(height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Heart rate chart")
                .accessibilityValue("Average \(Int(stats.average.rounded())), highest \(Int(stats.max.rounded())) beats per minute")
                HStack {
                    Label("Avg \(Int(stats.average.rounded()))", systemImage: "heart.fill")
                    Spacer()
                    Text("Max \(Int(stats.max.rounded())) bpm")
                }
                .snapText(.secondary)
                .monospacedDigit()
                Text("Thin lines are your sets. From Apple Health.").snapText(.secondary)
            }
        } else if let readings, readings.isEmpty {
            Card("Heart rate") {
                Text("No heart rate in Apple Health for this workout. Wear your Apple Watch and it shows up here.")
                    .snapText(.secondary)
            }
        }
    }

    // MARK: Compared with last time

    private struct Bar: Identifiable {
        let id: String
        let exercise: String
        let when: String
        let kg: Double
        let color: Color
    }

    private var bars: [Bar] {
        summary.exercises.filter { $0.topKg > 0 }.flatMap { result -> [Bar] in
            let up = result.lastTopKg.map { result.topKg > $0 + 0.001 } ?? false
            var rows = [Bar(id: result.id + "today", exercise: result.name, when: "Today", kg: unit.fromKg(result.topKg),
                            color: up ? Color.snap.statusUp : Color.snap.textPrimary)]
            if let last = result.lastTopKg {
                rows.insert(Bar(id: result.id + "last", exercise: result.name, when: "Last time", kg: unit.fromKg(last),
                                color: Color.snap.textSecondary.opacity(0.45)), at: 0)
            }
            return rows
        }
    }

    @ViewBuilder
    private var comparisonCard: some View {
        let bars = bars
        if !bars.isEmpty {
            let hasLast = summary.exercises.contains { $0.lastTopKg != nil && $0.topKg > 0 }
            Card(hasLast ? "Top weight vs last time" : "Top weight today") {
                if hasLast {
                    HStack(spacing: Snap.Spacing.l) {
                        LegendDot(color: Color.snap.textSecondary.opacity(0.45), label: "Last time")
                        LegendDot(color: Color.snap.textPrimary, label: "Today")
                        LegendDot(color: Color.snap.statusUp, label: "Heavier")
                    }
                }
                Chart(bars) { bar in
                    BarMark(x: .value(unit.rawValue, bar.kg), y: .value("Exercise", bar.exercise), height: .fixed(14))
                        .position(by: .value("When", bar.when))
                        .foregroundStyle(bar.color)
                        .cornerRadius(7)
                        .annotation(position: .trailing, spacing: Snap.Spacing.xs) {
                            Text(bar.kg.formatted(.number.precision(.fractionLength(0...1))))
                                .font(.caption.weight(.semibold))
                                .fontDesign(.rounded)
                                .monospacedDigit()
                                .foregroundStyle(bar.when == "Today" ? Color.snap.textPrimary : Color.snap.textSecondary)
                        }
                }
                .chartXAxis(.hidden)
                .chartXScale(domain: 0...((bars.map(\.kg).max() ?? 1) * 1.2))
                .chartYAxis {
                    AxisMarks { _ in AxisValueLabel().font(.subheadline) }
                }
                .frame(height: CGFloat(Set(bars.map(\.exercise)).count) * (hasLast ? 56 : 40))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Top weight per exercise")
                .accessibilityValue(comparisonDescription)
                Text("Weights in \(unit.rawValue). The heaviest set of each exercise.").snapText(.secondary)
            }
        }
    }

    private var comparisonDescription: String {
        summary.exercises.filter { $0.topKg > 0 }.map { result in
            let today = unit.format(kg: result.topKg)
            guard let last = result.lastTopKg else { return "\(result.name): \(today)" }
            return "\(result.name): \(today), last time \(unit.format(kg: last))"
        }.joined(separator: ". ")
    }

    // MARK: Bests, next time, exercises

    private var newBestsCard: some View {
        Card("New bests") {
            ForEach(summary.newBests) { result in
                HStack(spacing: Snap.Spacing.m) {
                    Image(systemName: "trophy.fill").foregroundStyle(Color.snap.statusUp).accessibilityHidden(true)
                    Text(result.name).snapText(.body)
                    Spacer()
                    Text(result.top.map { load($0) } ?? "").snapText(.body).monospacedDigit()
                }
                .foregroundStyle(Color.snap.textPrimary)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var nextTimeCard: some View {
        Card("Next time") {
            if summary.goingUp.isEmpty {
                Text("Same weights. Get one more rep on each set and the weight goes up.").snapText(.secondary)
            } else {
                ForEach(summary.goingUp) { result in
                    HStack(spacing: Snap.Spacing.m) {
                        Text(result.name).snapText(.body).foregroundStyle(Color.snap.textPrimary)
                        Spacer()
                        Text(result.nextKg.map { unit.format(kg: $0) } ?? "").snapText(.body).monospacedDigit()
                            .foregroundStyle(Color.snap.textPrimary)
                        StatusBadge(.up)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var exercisesCard: some View {
        Card("Your sets") {
            ForEach(summary.exercises) { result in
                VStack(alignment: .leading, spacing: Snap.Spacing.xs) {
                    Text(result.name).snapText(.sectionTitle).foregroundStyle(Color.snap.textPrimary)
                    Text(result.sets.map(load).joined(separator: ", ")).snapText(.secondary).monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func load(_ set: WorkoutSummary.SetResult) -> String {
        set.weightKg > 0 ? "\(unit.format(kg: set.weightKg)) × \(set.reps)" : "\(set.reps) reps"
    }
}

/// A titled block on the overview.
private struct Card<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Snap.Spacing.m) {
            Text(title).snapText(.sectionTitle).foregroundStyle(Color.snap.textPrimary).accessibilityAddTraits(.isHeader)
            content
        }
        .padding(Snap.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.snap.surface, in: .rect(cornerRadius: Snap.Radius.card))
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: Snap.Spacing.xs) {
            Image(systemName: symbol).foregroundStyle(Color.snap.textSecondary).accessibilityHidden(true)
            Text(value).snapText(.numberMedium).foregroundStyle(Color.snap.textPrimary).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).snapText(.secondary)
        }
        .padding(Snap.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.snap.surface, in: .rect(cornerRadius: Snap.Radius.card))
        .accessibilityElement(children: .combine)
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: Snap.Spacing.xs) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
        .snapText(.secondary)
    }
}

#if DEBUG
extension WorkoutSummary {
    /// Sample data for previews and snapshots.
    static func sample(now: Date = .now) -> WorkoutSummary {
        let start = now.addingTimeInterval(-52 * 60)
        func sets(_ kg: Double, _ reps: [Int], from minute: Double) -> [SetResult] {
            reps.enumerated().map { SetResult(weightKg: kg, reps: $1, loggedAt: start.addingTimeInterval((minute + Double($0) * 3) * 60)) }
        }
        return WorkoutSummary(
            routineName: "Upper and lower A",
            startedAt: start,
            finishedAt: now,
            activeSeconds: 48 * 60,
            setsPlanned: 9,
            exercises: [
                .init(id: "legs", name: "Leg Press", sets: sets(100, [12, 12, 12], from: 4), lastTopKg: 100, isNewBest: false, nextKg: 105),
                .init(id: "press", name: "Chest Press", sets: sets(47.5, [12, 11, 10], from: 18), lastTopKg: 45, isNewBest: true, nextKg: nil),
                .init(id: "row", name: "Seated Row", sets: sets(42.5, [12, 12, 9], from: 32), lastTopKg: 42.5, isNewBest: false, nextKg: nil),
            ],
            heartRateWindow: start...now
        )
    }

    /// A believable strength session: climbs during sets, settles in rests.
    static func sampleHeartRate(for summary: WorkoutSummary) -> [HeartRatePoint] {
        stride(from: 0.0, through: summary.finishedAt.timeIntervalSince(summary.startedAt), by: 30).map { offset in
            let date = summary.startedAt.addingTimeInterval(offset)
            let nearSet = summary.setTimes.map { abs($0.timeIntervalSince(date)) }.min() ?? 600
            let effort = max(0, 1 - nearSet / 90)
            return HeartRatePoint(date: date, bpm: 96 + min(offset / 60, 12) + effort * 48 + sin(offset / 47) * 4)
        }
    }
}

#Preview("Dark") {
    let summary = WorkoutSummary.sample()
    WorkoutSummaryView(summary: summary, heartRate: WorkoutSummary.sampleHeartRate(for: summary)) {}
        .preferredColorScheme(.dark)
}

#Preview("No heart rate, light") {
    WorkoutSummaryView(summary: .sample(), heartRate: []) {}
        .preferredColorScheme(.light)
}
#endif
