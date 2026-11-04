import Foundation
import HealthKit
import Intents
import Observation

/// The live heart rate for the Live Activity and the workout screen. Nil on iOS 18 to 25, with no Bluetooth heart rate strap, or while the phone
/// is locked when the person didn't allow workout data on a locked phone; the Lock Screen then shows only the clock.
enum LiveMetrics {
    @Observable final class Store { var heartRate: Int? }
    /// Observed, so the workout screen redraws with each new reading.
    static let store = Store()
    static var heartRate: Int? {
        get { store.heartRate }
        set { store.heartRate = newValue }
    }
    /// Set by the app at launch: redraws the Live Activity after a new reading.
    static var onChange: (@MainActor () -> Void)?
}

/// iOS 26 and later: runs the workout as a live HealthKit session on the phone, as Apple's own Workout app does.
/// That adds the system's calorie count, a paired Bluetooth heart rate strap, crash recovery, and the Lock Screen's
/// Siri workout controls. iOS 18 to 25, or a workout with no live session, keep the plain save in `Health.saveWorkout`.
///
/// Snapset's own `WorkoutSession` stays the source of truth: this follows it (start, pause, resume) and never leads.
@available(iOS 26.0, *)
@MainActor
final class LiveWorkout: NSObject {
    static let shared = LiveWorkout()

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    /// The `WorkoutSession.startedAt` the live session runs for; nil while it is only prepared.
    private var startedAt: Date?
    private var starting = false
    private var finishing = false
    private var triedRecovery = false
    /// Bumped when a countdown is cancelled, so a prepare still waiting on the permission sheet doesn't go on.
    private var prepareToken = 0
    private var stopped: CheckedContinuation<Void, Never>?
    private var lastPublished = Date.distantPast

    private var isOn: Bool { UserDefaults.standard.object(forKey: "saveToHealth") as? Bool ?? true }

    func isRunning(for start: Date) -> Bool {
        guard let session, let startedAt, !finishing else { return false }
        return abs(startedAt.timeIntervalSince(start)) < 1 && (session.state == .running || session.state == .paused)
    }

    /// Calories the live session has measured so far, for the overview; nil when no live session runs for this workout.
    /// Read before `finish`, which stops the session.
    func measuredKcal(startedAt start: Date) -> Double? {
        guard isRunning(for: start) else { return nil }
        return builder?.statistics(for: Health.energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
    }

    // MARK: Following Snapset's workout

    /// During the countdown: the system gets its sensors and a paired heart rate strap ready, so readings start at 0:00.
    func prepare() {
        guard isOn, session == nil else { return }
        let token = prepareToken
        Task {
            guard await Health.requestAccess(), token == prepareToken, session == nil, let session = makeSession() else { return }
            session.prepare()
        }
    }

    /// The countdown was cancelled.
    func cancelPrepared() {
        prepareToken += 1
        guard let session, startedAt == nil else { return }
        session.end()
        clear()
    }

    /// Keeps the live session in step with Snapset's workout: starts it, or picks up the one a crash left, and pauses
    /// and resumes with it. Rest is not a pause: Health counts rest as part of a strength workout.
    func follow(startedAt start: Date, paused: Bool) {
        guard isOn, !finishing else { return }
        if isRunning(for: start) {
            if paused, session?.state == .running { session?.pause() }
            if !paused, session?.state == .paused { session?.resume() }
            return
        }
        guard !starting else { return }
        starting = true
        Task {
            defer { starting = false }
            guard await Health.requestAccess() else { return }
            if !triedRecovery {
                triedRecovery = true
                await recover()  // the app was relaunched mid-workout
            }
            if !isRunning(for: start), startedAt != nil { discardCurrent() }  // left over from another workout
            if !isRunning(for: start) { await begin(at: start) }
            if isRunning(for: start), paused { session?.pause() }
        }
    }

    /// The workout was thrown away (no set logged): nothing goes to Health.
    func discard(startedAt start: Date) {
        guard isRunning(for: start) else { return }
        discardCurrent()
    }

    /// No workout is running in Snapset, so a live session still going belongs to nothing.
    func discardOrphan() {
        guard !finishing, !starting, startedAt != nil else { return }
        discardCurrent()
    }

    /// Ends the live session and saves it with the same metadata, exercise activities and calories as the plain save.
    /// Returns false, doing nothing, when no live session runs for this workout; the caller then saves the plain way.
    func finish(startedAt start: Date, record: Health.WorkoutRecord) -> Bool {
        guard isRunning(for: start), let session, let builder else { return false }
        finishing = true
        session.stopActivity(with: record.end)
        Task { await save(session, builder, record) }
        return true
    }

    // MARK: Crash recovery

    /// Picks up the session HealthKit kept running while the app was gone. Called at launch when iOS says a workout
    /// needs recovering, and once before the first start, which also covers a force quit.
    func recover() async {
        guard session == nil else { return }
        let recovered: HKWorkoutSession? = await withCheckedContinuation { continuation in
            Health.store.recoverActiveWorkoutSession { session, _ in continuation.resume(returning: session) }
        }
        guard let recovered, session == nil else { return }
        attach(recovered)  // the builder comes back with the session; its data source has to be set again
        startedAt = recovered.startDate
    }

    // MARK: Private

    private func begin(at start: Date) async {
        guard let session = session ?? makeSession(), let builder else { return }
        startedAt = start
        session.startActivity(with: start)
        do {
            try await builder.beginCollection(at: start)
        } catch {
            discardCurrent()
            return
        }
        // Siri, and the Lock Screen's pause and resume, reach Snapset through its workout intents. iOS asks once.
        INPreferences.requestSiriAuthorization { _ in }
    }

    private func makeSession() -> HKWorkoutSession? {
        guard let session = try? HKWorkoutSession(healthStore: Health.store, configuration: Health.configuration) else { return nil }
        attach(session)
        return session
    }

    private func attach(_ session: HKWorkoutSession) {
        let builder = session.associatedWorkoutBuilder()
        session.delegate = self
        builder.delegate = self
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: Health.store, workoutConfiguration: session.workoutConfiguration)
        self.session = session
        self.builder = builder
    }

    private func save(_ session: HKWorkoutSession, _ builder: HKLiveWorkoutBuilder, _ record: Health.WorkoutRecord) async {
        // The builder may only end once the session has stopped. A session that never says so is given 5 seconds.
        if session.state != .stopped {
            await withCheckedContinuation { continuation in
                stopped = continuation
                Task {
                    try? await Task.sleep(for: .seconds(5))
                    resumeStopped()
                }
            }
        }
        let kcal = builder.statistics(for: Health.energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
        await Health.fill(builder, with: record, measuredKcal: kcal)
        do {
            try await builder.endCollection(at: record.end)
            if let workout = try await builder.finishWorkout() { await Health.didSave(workout) }
        } catch {
            builder.discardWorkout()
        }
        session.end()
        clear()
        LiveMetrics.onChange?()  // a workout started while this one was saving gets its own session now
    }

    private func resumeStopped() {
        stopped?.resume()
        stopped = nil
    }

    private func discardCurrent() {
        builder?.discardWorkout()
        session?.end()
        clear()
    }

    private func clear() {
        session = nil
        builder = nil
        startedAt = nil
        finishing = false
        LiveMetrics.heartRate = nil
    }

    /// Live Activity updates are rationed, so a changed reading goes out every 10 seconds at most.
    private func publish(_ bpm: Int) {
        let old = LiveMetrics.heartRate
        LiveMetrics.heartRate = bpm
        guard old != bpm, Date.now.timeIntervalSince(lastPublished) >= 10 else { return }
        lastPublished = .now
        LiveMetrics.onChange?()
    }
}

@available(iOS 26.0, *)
extension LiveWorkout: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState, date: Date) {
        guard toState == .stopped else { return }
        Task { @MainActor in self.resumeStopped() }
    }

    /// Another app started a workout, or HealthKit gave up: Finish then saves the plain way.
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        Task { @MainActor in
            guard self.session === workoutSession, !self.finishing else { return }
            self.clear()
        }
    }
}

@available(iOS 26.0, *)
extension LiveWorkout: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard collectedTypes.contains(Health.heartRateType),
              let quantity = workoutBuilder.statistics(for: Health.heartRateType)?.mostRecentQuantity() else { return }
        let bpm = Int(quantity.doubleValue(for: .count().unitDivided(by: .minute())).rounded())
        Task { @MainActor in self.publish(bpm) }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
