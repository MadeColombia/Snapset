import Foundation
import HealthKit

/// Apple Health: write finished workouts, read the Watch's heart rate and energy. Every failure is silent; Health is optional.
enum Health {
    static let store = HKHealthStore()
    static let heartRateType = HKQuantityType(.heartRate)
    static let energyType = HKQuantityType(.activeEnergyBurned)
    private static let bodyMassType = HKQuantityType(.bodyMass)
    private static let effortType = HKQuantityType(.workoutEffortScore)

    /// The workout saved at the last finish, so the effort picked on the overview can be attached to it.
    @MainActor private static var lastWorkout: HKWorkout?
    /// An effort picked before the workout finished saving; attached as soon as it is saved.
    @MainActor private static var pendingEffort: (score: Int, end: Date)?

    /// iOS shows the permission sheet only the first time; later calls return at once.
    /// Asked during onboarding, so the first finished workout isn't interrupted by it.
    /// Types added later (energy, effort, body mass, heart rate) get one more sheet the next time this runs.
    @discardableResult
    static func requestAccess() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        var share: Set<HKSampleType> = [HKObjectType.workoutType(), energyType, effortType]
        // iOS 26 runs the workout live, and saves the heart rate of a paired Bluetooth strap under Snapset.
        if #available(iOS 26.0, *) { share.insert(heartRateType) }
        do {
            try await store.requestAuthorization(toShare: share, read: [heartRateType, energyType, bodyMassType])
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

    /// A run of back-to-back sets of one exercise, saved as one activity inside the workout.
    struct ExerciseBlock: Equatable {
        let name: String
        let start: Date
        let end: Date
        let sets: Int
    }

    /// Splits the logged sets into runs of one exercise, in order. Each block runs from the end of the one before
    /// (the workout start for the first) to its last set, so the blocks never overlap, as HealthKit requires,
    /// and the rest before a set counts toward that set's exercise. A superset makes one short block per set.
    static func exerciseBlocks(_ sets: [(name: String, at: Date)], workoutStart: Date) -> [ExerciseBlock] {
        var blocks: [ExerciseBlock] = []
        for set in sets.sorted(by: { $0.at < $1.at }) {
            if let last = blocks.last, last.name == set.name {
                blocks[blocks.count - 1] = ExerciseBlock(name: last.name, start: last.start, end: set.at, sets: last.sets + 1)
            } else {
                let start = max(blocks.last?.end ?? workoutStart, workoutStart)
                blocks.append(ExerciseBlock(name: set.name, start: start, end: max(set.at, start), sets: 1))
            }
        }
        return blocks
    }

    /// Ties a workout in Health to its session, so saving the same session again replaces it instead of adding a second one.
    static func syncIdentifier(sessionStartedAt: Date) -> String {
        "snapset.workout.\(Int((sessionStartedAt.timeIntervalSince1970 * 1_000).rounded()))"
    }

    /// Everything a finished workout sends to Health, the same for the plain save and the live session.
    struct WorkoutRecord {
        let start: Date
        let end: Date
        /// The routine name exactly as the person typed it; Snapset adds and strips nothing.
        let name: String?
        let activeSeconds: TimeInterval
        let syncIdentifier: String
        let blocks: [ExerciseBlock]
    }

    static let configuration: HKWorkoutConfiguration = {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        return configuration
    }()

    /// Saves a Traditional Strength Training workout after the fact (iOS 18 to 25, or when no live session ran):
    /// its active calories, one activity for each exercise block, and the routine name in its metadata.
    /// Fitness shows that name on the Sessions list; its detail page always shows the activity type, and no public API changes that.
    static func saveWorkout(_ record: WorkoutRecord) async {
        guard await requestAccess() else { return }
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        do {
            try await builder.beginCollection(at: record.start)
            await fill(builder, with: record, measuredKcal: nil)
            try await builder.endCollection(at: record.end)
            guard let workout = try await builder.finishWorkout() else { return }
            await didSave(workout)
        } catch {
            builder.discardWorkout()
        }
    }

    /// Metadata, exercise activities and calories, shared by both ways of saving. `measuredKcal` is what a live
    /// session already collected; when it has nothing, the Watch's reading or Snapset's estimate is added instead.
    static func fill(_ builder: HKWorkoutBuilder, with record: WorkoutRecord, measuredKcal: Double?) async {
        var metadata: [String: Any] = [
            HKMetadataKeyIndoorWorkout: true,
            HKMetadataKeySyncIdentifier: record.syncIdentifier,
            HKMetadataKeySyncVersion: 1,
        ]
        if let name = record.name, !name.isEmpty { metadata[HKMetadataKeyWorkoutBrandName] = name }
        try? await builder.addMetadata(metadata)
        for block in record.blocks where block.start >= (builder.startDate ?? record.start) && block.end <= record.end && block.end > block.start {
            // The custom keys are for apps that read them; Health keeps keys that don't start with "HK".
            let activity = HKWorkoutActivity(workoutConfiguration: configuration, start: block.start, end: block.end,
                                             metadata: ["SnapsetExercise": block.name, "SnapsetSets": block.sets])
            try? await builder.addWorkoutActivity(activity)  // an activity Health refuses must not cost the workout
        }
        if let measuredKcal, measuredKcal > 0 { return }
        // Fitness shows only calories attached to the workout itself, so they are always written:
        // the Watch's own reading when there is one, else the estimate. Health counts overlapping
        // calories from different sources once, by source priority, so the day's total isn't doubled.
        let energy = await energy(from: record.start, to: record.end, activeSeconds: record.activeSeconds)
        let sample = HKQuantitySample(type: energyType, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: energy.kcal),
                                      start: record.start, end: record.end)
        try? await builder.addSamples([sample])  // calories turned off in Health must not cost the workout
    }

    /// Remembers the saved workout for the effort picked on the overview, and attaches an effort picked while it was saving.
    @MainActor
    static func didSave(_ workout: HKWorkout) async {
        lastWorkout = workout
        if let pending = pendingEffort, covers(workout, pending.end) {
            pendingEffort = nil
            await saveEffort(pending.score, workoutEnd: pending.end)
        }
    }

    /// The overview knows the workout by the end of its active window. A live workout ends when Finish is tapped,
    /// which can be later than that window, so any end inside the workout counts.
    private static func covers(_ workout: HKWorkout, _ end: Date) -> Bool {
        end >= workout.startDate.addingTimeInterval(-1) && end <= workout.endDate.addingTimeInterval(1)
    }

    /// Attaches how hard the workout felt (1 to 10, as in the Fitness app) to the workout that ended at `workoutEnd`.
    /// Picking again adds a newer score, and Health shows the latest.
    @MainActor
    static func saveEffort(_ score: Int, workoutEnd: Date) async {
        guard let workout = lastWorkout, covers(workout, workoutEnd) else {
            pendingEffort = (score, workoutEnd)  // still saving; didSave picks it up
            return
        }
        guard await requestAccess() else { return }
        let sample = HKQuantitySample(type: effortType, quantity: HKQuantity(unit: .appleEffortScore(), doubleValue: Double(score)),
                                      start: workout.startDate, end: workout.endDate)
        _ = try? await store.relateWorkoutEffortSample(sample, with: workout, activity: nil)
    }

    /// Deletes the workout Snapset saved for a session, with the calories, effort and heart rate Snapset attached to it.
    /// Found by its sync identifier; workouts saved before that existed are found by their start and end.
    /// Only Snapset's own data: anything a Watch recorded stays.
    static func deleteWorkout(syncIdentifier: String, start: Date, end: Date) async {
        guard await requestAccess() else { return }
        let mine = HKQuery.predicateForObjects(from: HKSource.default())
        let byID = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: [syncIdentifier])
        let byTime = HKQuery.predicateForSamples(withStart: start.addingTimeInterval(-1), end: end.addingTimeInterval(1))
        let either = NSCompoundPredicate(orPredicateWithSubpredicates: [byID, byTime])
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(NSCompoundPredicate(andPredicateWithSubpredicates: [mine, either]))],
                                                 sortDescriptors: [])
        let workouts = ((try? await descriptor.result(for: store)) ?? []).filter {
            $0.metadata?[HKMetadataKeySyncIdentifier] as? String == syncIdentifier
                || (abs($0.startDate.timeIntervalSince(start)) < 1 && abs($0.endDate.timeIntervalSince(end)) < 1)
        }
        guard !workouts.isEmpty else { return }
        for workout in workouts {
            let window = HKQuery.predicateForSamples(withStart: workout.startDate.addingTimeInterval(-1), end: workout.endDate.addingTimeInterval(1))
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [mine, window])
            for type in [energyType, effortType, heartRateType] {
                _ = try? await store.deleteObjects(of: type, predicate: predicate)
            }
        }
        try? await store.delete(workouts)
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
