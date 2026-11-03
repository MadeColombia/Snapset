import Foundation
import HealthKit

/// Apple Health: write finished workouts, read the Watch's heart rate and energy. Every failure is silent; Health is optional.
enum Health {
    private static let store = HKHealthStore()
    private static let heartRateType = HKQuantityType(.heartRate)
    private static let energyType = HKQuantityType(.activeEnergyBurned)
    private static let bodyMassType = HKQuantityType(.bodyMass)
    private static let effortType = HKQuantityType(.workoutEffortScore)

    /// The workout saved at the last finish, so the effort picked on the overview can be attached to it.
    @MainActor private static var lastWorkout: HKWorkout?
    /// An effort picked before the workout finished saving; attached as soon as it is saved.
    @MainActor private static var pendingEffort: (score: Int, end: Date)?

    /// iOS shows the permission sheet only the first time; later calls return at once.
    /// Asked during onboarding, so the first finished workout isn't interrupted by it.
    /// Types added later (energy, effort, body mass) get one more sheet the next time this runs.
    @discardableResult
    static func requestAccess() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: [HKObjectType.workoutType(), energyType, effortType],
                                                 read: [heartRateType, energyType, bodyMassType])
            return true
        } catch {
            return false
        }
    }

    struct Energy: Equatable {
        let kcal: Double
        /// True when a Watch (or another app) measured it; false for Snapset's estimate.
        let measured: Bool
    }

    /// Active calories for a workout: what other sources (the Watch) measured in the window if anything,
    /// otherwise an estimate from the workout time and body weight.
    static func energy(from start: Date, to end: Date, activeSeconds: TimeInterval) async -> Energy {
        let measured = await activeEnergy(from: start, to: end)
        if let measured, measured > 0 { return Energy(kcal: measured, measured: true) }
        return Energy(kcal: estimatedKcal(activeSeconds: activeSeconds, bodyKg: await latestBodyMassKg()), measured: false)
    }

    /// Active energy for strength training at a moderate pace: (MET 3.5 − 1 resting) × kg × hours.
    /// shortcut: one MET for every routine; upgrade with the effort score or heart rate if estimates feel off.
    static func estimatedKcal(activeSeconds: TimeInterval, bodyKg: Double?) -> Double {
        (3.5 - 1) * (bodyKg ?? 70) * activeSeconds / 3_600
    }

    /// Saves a Traditional Strength Training workout with its active calories and the routine name in its metadata.
    /// Fitness titles third-party workouts by activity type, so the name shows only to apps that read the metadata.
    static func saveWorkout(start: Date, end: Date, name: String?, activeSeconds: TimeInterval) async {
        guard await requestAccess() else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        do {
            try await builder.beginCollection(at: start)
            var metadata: [String: Any] = [HKMetadataKeyIndoorWorkout: true]
            if let name, !name.isEmpty { metadata[HKMetadataKeyWorkoutBrandName] = name }
            try? await builder.addMetadata(metadata)
            // Fitness shows only calories attached to the workout itself, so they are always written:
            // the Watch's own reading when there is one, else the estimate. Health counts overlapping
            // calories from different sources once, by source priority, so the day's total isn't doubled.
            let energy = await energy(from: start, to: end, activeSeconds: activeSeconds)
            let sample = HKQuantitySample(type: energyType, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: energy.kcal),
                                          start: start, end: end)
            try? await builder.addSamples([sample])  // calories turned off in Health must not cost the workout
            try await builder.endCollection(at: end)
            guard let workout = try await builder.finishWorkout() else { return }
            await MainActor.run { lastWorkout = workout }
            if let pending = await pendingEffort, abs(pending.end.timeIntervalSince(workout.endDate)) < 1 {
                await MainActor.run { pendingEffort = nil }
                await saveEffort(pending.score, workoutEnd: pending.end)
            }
        } catch {
            builder.discardWorkout()
        }
    }

    /// Attaches how hard the workout felt (1 to 10, as in the Fitness app) to the workout that ended at `workoutEnd`.
    /// Picking again adds a newer score, and Health shows the latest.
    @MainActor
    static func saveEffort(_ score: Int, workoutEnd: Date) async {
        guard let workout = lastWorkout, abs(workout.endDate.timeIntervalSince(workoutEnd)) < 1 else {
            pendingEffort = (score, workoutEnd)  // still saving; saveWorkout picks it up
            return
        }
        guard await requestAccess() else { return }
        let sample = HKQuantitySample(type: effortType, quantity: HKQuantity(unit: .appleEffortScore(), doubleValue: Double(score)),
                                      start: workout.startDate, end: workout.endDate)
        try? await store.relateWorkoutEffortSample(sample, with: workout, activity: nil)
    }

    /// Active energy other sources recorded in the window, leaving out Snapset's own estimates.
    private static func activeEnergy(from start: Date, to end: Date) async -> Double? {
        guard await requestAccess() else { return nil }
        let notMine = NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(from: HKSource.default()))
        let window = HKQuery.predicateForSamples(withStart: start, end: end)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [window, notMine])
        let query = HKStatisticsQueryDescriptor(predicate: .quantitySample(type: energyType, predicate: predicate), options: .cumulativeSum)
        return (try? await query.result(for: store))?.sumQuantity()?.doubleValue(for: .kilocalorie())
    }

    private static func latestBodyMassKg() async -> Double? {
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: bodyMassType)],
                                                 sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)], limit: 1)
        return (try? await descriptor.result(for: store))?.first?.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }

    /// Average and max bpm Health has between `start` and `end`, or nil when there are no readings or no permission.
    static func heartRate(from start: Date, to end: Date) async -> (average: Double, max: Double)? {
        guard await requestAccess() else { return nil }
        let samples = HKSamplePredicate.quantitySample(type: heartRateType, predicate: HKQuery.predicateForSamples(withStart: start, end: end))
        let query = HKStatisticsQueryDescriptor(predicate: samples, options: [.discreteAverage, .discreteMax])
        guard let stats = try? await query.result(for: store),
              let average = stats.averageQuantity(), let max = stats.maximumQuantity() else { return nil }
        let bpm = HKUnit.count().unitDivided(by: .minute())
        return (average.doubleValue(for: bpm), max.doubleValue(for: bpm))
    }

    /// Every heart rate reading between `start` and `end`, oldest first; empty with no readings or no permission.
    static func heartRateSamples(from start: Date, to end: Date) async -> [HeartRatePoint] {
        guard await requestAccess() else { return [] }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: heartRateType, predicate: HKQuery.predicateForSamples(withStart: start, end: end))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        guard let samples = try? await descriptor.result(for: store) else { return [] }
        let bpm = HKUnit.count().unitDivided(by: .minute())
        return samples.map { HeartRatePoint(date: $0.startDate, bpm: $0.quantity.doubleValue(for: bpm)) }
    }
}

struct HeartRatePoint: Hashable {
    let date: Date
    let bpm: Double
}
