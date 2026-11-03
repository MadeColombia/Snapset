import Charts
import SwiftUI
import SnapsetUI

/// The overview after Finish: the workout's highlight, time, calories, rest and heart rate,
/// how hard it felt, today's top weights against last time, and what goes up next time.
struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    /// Readings to show without asking Health, for previews and snapshots; nil loads them.
    var heartRate: [HeartRatePoint]?
    /// Calories to show without asking Health, for previews and snapshots; nil loads them.
    var energy: Health.Energy?
    /// How hard it felt, 1 to 10, when the lifter picks it.
    var onEffort: (Int) -> Void = { _ in }
    let onDone: () -> Void

    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    @State private var loaded: [HeartRatePoint]?
    @State private var loadedEnergy: Health.Energy?
    @State private var effort: Int?
    @State private var cheered = false

    private var readings: [HeartRatePoint]? { heartRate ?? loaded }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Snap.Spacing.l) {
                header
                highlightCard
                stats
                effortCard
                heartRateCard
                restCard
                comparisonCard
                if summary.newBests.count > 1 { newBestsCard }  // one best is already the highlight
                nextTimeCard
                exercisesCard
            }
            .padding(Snap.Spacing.l)
        }
        .background(Color.snap.background)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton("Done", systemImage: "checkmark", style: .finish, action: onDone)
                .padding(.horizontal, Snap.Spacing.l)
                .padding(.vertical, Snap.Spacing.s)
                .background(Color.snap.background)
        }
        .task {
            guard energy == nil else { return }
            let window = summary.heartRateWindow
            loadedEnergy = await Health.energy(from: window.lowerBound, to: window.upperBound, activeSeconds: summary.activeSeconds)
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
        }
    }

    /// The workout's one cheer: the biggest upgrade, else what goes up, else the effort itself.
    private var highlightCard: some View {
        let highlight = summary.highlight
        return HStack(alignment: .top, spacing: Snap.Spacing.m) {
            Image(systemName: summary.newBests.isEmpty ? "arrow.up.circle.fill" : "trophy.fill")
                .font(.title)
                .foregroundStyle(Color.snap.statusUp)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Snap.Spacing.xs) {
                Text(highlight.title).snapText(.sectionTitle).foregroundStyle(Color.snap.textPrimary)
                Text(highlight.detail).snapText(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Snap.Spacing.l)
        .background(Color.snap.surface, in: .rect(cornerRadius: Snap.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Snap.Radius.card).fill(Color.snap.statusUp.opacity(0.1)).allowsHitTesting(false))
        .overlay(RoundedRectangle(cornerRadius: Snap.Radius.card).stroke(Color.snap.statusUp.opacity(0.6)))
        .accessibilityElement(children: .combine)
    }

    private var currentEnergy: Health.Energy? { energy ?? loadedEnergy }

    private var stats: some View {
        let columns = [GridItem(.adaptive(minimum: 150), spacing: Snap.Spacing.s)]
        return LazyVGrid(columns: columns, spacing: Snap.Spacing.s) {
            StatTile(value: Self.workoutTime(summary.activeSeconds), label: "Workout time",
                     symbol: "stopwatch.fill", tint: Color.snap.statusHold)
            StatTile(value: currentEnergy.map { "\(Int($0.kcal.rounded())) kcal" } ?? "…",
                     label: currentEnergy?.measured == false ? "Active calories (estimate)" : "Active calories",
                     symbol: "flame.fill", tint: Color.snap.statusDown)
            StatTile(value: summary.averageRest.map(Self.clock) ?? "–", label: restLabel, symbol: "timer", tint: restTint)
            if let stats = heartRateStats {
                // Orange, like the heart rate line it sums up.
                StatTile(value: "\(Int(stats.average.rounded())) bpm", label: "Average heart rate",
                         symbol: "heart.fill", tint: Color.snap.accent)
            } else {
                StatTile(value: "\(summary.newBests.count)", label: summary.newBests.count == 1 ? "New best" : "New bests",
                         symbol: "trophy.fill", tint: Color.snap.statusUp)
            }
        }
    }

    private var restLabel: String {
        switch summary.restVerdict {
        case .short: "Average rest, short"
        case .onPoint: "Average rest, on point"
        case .long: "Average rest, long"
        case nil: "Average rest"
        }
    }

    /// Green when the rest was on point, amber when it was off, blue with nothing to judge.
    private var restTint: Color {
        switch summary.restVerdict {
        case .onPoint: Color.snap.statusUp
        case .short, .long: Color.snap.statusDown
        case nil: Color.snap.statusHold
        }
    }

    /// Seconds for a very short workout, so a quick one doesn't read "0 min".
    static func workoutTime(_ seconds: TimeInterval) -> String {
        seconds < 60
            ? Duration.seconds(seconds.rounded()).formatted(.units(allowed: [.seconds], width: .abbreviated))
            : Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    static func clock(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds.rounded()).formatted(.time(pattern: .minuteSecond))
    }

    // MARK: Effort

    private static let effortWords = [1: "Easy", 4: "Moderate", 7: "Hard", 9: "All out"]
    /// Easy in green, moderate in blue, hard in amber: the filled bar warms up as the score climbs.
    static func effortTint(_ score: Int) -> Color {
        switch score {
        case ...3: Color.snap.statusUp
        case 4...6: Color.snap.statusHold
        default: Color.snap.statusDown
        }
    }

    private static func effortWord(_ score: Int) -> String {
        effortWords.filter { $0.key <= score }.max { $0.key < $1.key }?.value ?? "Easy"
    }

    /// How hard it felt, on the Fitness app's 1 to 10 scale, saved with the workout in Apple Health.
    private var effortCard: some View {
        Card("How hard was it?", symbol: "gauge.with.dots.needle.67percent", tint: effort.map(Self.effortTint) ?? Color.snap.statusHold) {
            HStack(spacing: Snap.Spacing.xs) {
                ForEach(1...10, id: \.self) { score in
                    Button {
                        effort = score
                        onEffort(score)
                    } label: {
                        Text("\(score)")
                            .font(.subheadline.weight(.semibold))
                            .fontDesign(.rounded)
                            .frame(maxWidth: .infinity, minHeight: Snap.Tap.min)
                            .foregroundStyle(effort.map { score <= $0 } == true ? Color.snap.onAccent : Color.snap.textPrimary)
                            .background(effort.map { score <= $0 } == true ? Self.effortTint(score) : Color.snap.surfaceRaised,
                                        in: .rect(cornerRadius: Snap.Radius.chip))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(score), \(Self.effortWord(score))")
                    .accessibilityAddTraits(effort == score ? .isSelected : [])
                }
            }
            .sensoryFeedback(Snap.Haptic.stepperChange, trigger: effort)
            Text(effort.map { "\(Self.effortWord($0)). Saved with this workout in Apple Health." }
                 ?? "1 is easy, 10 is all out. It goes to Apple Health with the workout.")
                .snapText(.secondary)
        }
    }

    // MARK: Rest

    @ViewBuilder
    private var restCard: some View {
        let gaps = summary.restGaps
        if gaps.count > 1, let average = summary.averageRest {
            let target = summary.targetRestSeconds
            Card("Rest between sets", symbol: "timer", tint: restTint) {
                Chart {
                    ForEach(Array(gaps.enumerated()), id: \.offset) { index, gap in
                        BarMark(x: .value("Rest", index + 1), y: .value("Seconds", gap / 60), width: .ratio(0.6))
                            .foregroundStyle(gap > target * 1.5 || gap < target * 0.75 ? Color.snap.statusDown : Color.snap.textSecondary.opacity(0.5))
                            .cornerRadius(4)
                    }
                    RuleMark(y: .value("Plan", target / 60))
                        .foregroundStyle(Color.snap.textPrimary)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Plan \(Self.clock(target))").font(.caption).foregroundStyle(Color.snap.textSecondary)
                        }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine()
                        AxisValueLabel { if let minutes = value.as(Double.self) { Text("\(minutes.formatted()) min") } }
                    }
                }
                .frame(height: 140)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rest between sets")
                .accessibilityValue("Average \(Self.clock(average)), plan \(Self.clock(target))")
                Text(restAdvice(average: average, target: target)).snapText(.secondary)
            }
        }
    }

    private func restAdvice(average: TimeInterval, target: TimeInterval) -> String {
        switch summary.restVerdict {
        case .long:
            "Your rests averaged \(Self.clock(average)), the plan is \(Self.clock(target)). Start the next set when the timer ends and the workout gets shorter."
        case .short:
            "Your rests averaged \(Self.clock(average)), the plan is \(Self.clock(target)). Take the full rest: you'll lift more on the next set."
        default:
            "Your rests averaged \(Self.clock(average)), right on the plan of \(Self.clock(target)). Amber bars are the ones far off."
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
            Card("Heart rate", symbol: "heart.fill", tint: Color.snap.accent) {
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
            Card("Heart rate", symbol: "heart.fill", tint: Color.snap.accent) {
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
        Card("New bests", symbol: "trophy.fill", tint: Color.snap.statusUp) {
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
        Card("Next time", symbol: "arrow.up.circle.fill", tint: Color.snap.statusUp) {
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
        Card("Your sets", symbol: "list.bullet", tint: Color.snap.statusHold) {
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
    let symbol: String?
    let tint: Color
    @ViewBuilder let content: Content

    init(_ title: String, symbol: String? = nil, tint: Color = Color.snap.textSecondary, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Snap.Spacing.m) {
            HStack(spacing: Snap.Spacing.s) {
                if let symbol { IconBadge(symbol: symbol, tint: tint) }
                Text(title).snapText(.sectionTitle).foregroundStyle(Color.snap.textPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            content
        }
        .padding(Snap.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.snap.surface, in: .rect(cornerRadius: Snap.Radius.card))
    }
}

/// A tinted circle behind a symbol: the colour that tells the overview's blocks apart at a glance.
private struct IconBadge: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(tint.opacity(0.18), in: .circle)
            .accessibilityHidden(true)
    }
}

/// Every tile is the same size: the label always keeps room for two lines, so a long one doesn't make its tile taller.
private struct StatTile: View {
    let value: String
    let label: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Snap.Spacing.s) {
            IconBadge(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: Snap.Spacing.xs) {
                Text(value).snapText(.numberMedium).foregroundStyle(Color.snap.textPrimary).lineLimit(1).minimumScaleFactor(0.6)
                Text(label).snapText(.secondary).lineLimit(2, reservesSpace: true)
            }
        }
        .padding(Snap.Spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
    WorkoutSummaryView(summary: summary, heartRate: WorkoutSummary.sampleHeartRate(for: summary),
                       energy: .init(kcal: 312, measured: true)) {}
        .preferredColorScheme(.dark)
}

#Preview("No heart rate, light") {
    WorkoutSummaryView(summary: .sample(), heartRate: [], energy: .init(kcal: 168, measured: false)) {}
        .preferredColorScheme(.light)
}
#endif
