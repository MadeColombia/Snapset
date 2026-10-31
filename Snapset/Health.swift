import Foundation
import HealthKit

/// Apple Health: write finished workouts, read the Watch's heart rate. Every failure is silent; Health is optional.
enum Health {
    private static let store = HKHealthStore()
    private static let heartRateType = HKQuantityType(.heartRate)

    /// iOS shows the permission sheet only the first time; later calls return at once.
    private static func requestAccess() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [heartRateType])
            return true
        } catch {
            return false
        }
    }

    static func saveWorkout(start: Date, end: Date) async {
        guard await requestAccess() else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        do {
            try await builder.beginCollection(at: start)
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {
            builder.discardWorkout()
        }
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
}
