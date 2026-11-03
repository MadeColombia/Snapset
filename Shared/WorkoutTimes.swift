import Foundation

/// The workout's two clocks, as plain values shared by the app, the widget and the tests.
///
/// The workout clock keeps running through rests, so the total activity time stays clear; only Pause stops it.
/// The rest clock counts down on its own, next to it. Pause freezes both; Resume carries both on.
/// A rest ends on a whole second of the workout clock, so the two clocks always change digits together.
struct WorkoutTimes: Codable, Hashable {
    var startedAt: Date
    /// Closed pauses, left out of the workout time.
    var stoppedSeconds: Double = 0
    /// The workout clock has stood still since then (a pause). Nil while it runs.
    var holdSince: Date?
    var pausedAt: Date?
    var restEndsAt: Date?
    /// The rest's full length, for the ring.
    var restSeconds: Double = 0

    enum Phase: Equatable { case training, resting, paused }

    func phase(at now: Date = .now) -> Phase {
        if pausedAt != nil { return .paused }
        return restRemaining(at: now) == nil ? .training : .resting
    }

    /// Seconds of rest left at `now`, frozen while paused; nil when no rest is running.
    func restRemaining(at now: Date = .now) -> TimeInterval? {
        guard let restEndsAt else { return nil }
        let left = restEndsAt.timeIntervalSince(pausedAt ?? now)
        return left > 0 ? left : nil
    }

    /// A rest that ran out while not paused.
    private func restOver(at now: Date) -> Bool {
        guard pausedAt == nil, let restEndsAt else { return false }
        return restEndsAt <= now
    }

    /// When a running workout clock read 0:00 (for a self-updating timer text); nil while paused.
    func runningSince(at now: Date = .now) -> Date? {
        holdSince == nil ? startedAt.addingTimeInterval(stoppedSeconds) : nil
    }

    /// Workout time at `now`, without pauses.
    func elapsed(at now: Date = .now) -> TimeInterval {
        if let since = runningSince(at: now) { return max(0, now.timeIntervalSince(since)) }
        return max(0, (holdSince ?? now).timeIntervalSince(startedAt) - stoppedSeconds)
    }

    /// A start for once-a-second timeline views, in the past and on the clocks' shared second,
    /// so every number on screen changes at the same moment as the rest's last second runs out.
    var tickStart: Date {
        (restEndsAt ?? runningSince() ?? .now).addingTimeInterval(-86_400)
    }

    // MARK: Changes. Each one first closes a rest that ran out, so the order of events never matters.

    /// Clears a rest that ran out before `now`.
    mutating func settle(at now: Date = .now) {
        if restOver(at: now) { restEndsAt = nil }
    }

    mutating func togglePause(at now: Date = .now) {
        settle(at: now)
        if let pausedAt {
            let paused = now.timeIntervalSince(pausedAt)
            self.pausedAt = nil
            // Both clocks carry on from where they stood: the rest keeps what it had left.
            if let restEndsAt { self.restEndsAt = restEndsAt.addingTimeInterval(paused) }
            stoppedSeconds += now.timeIntervalSince(holdSince ?? pausedAt)
            holdSince = nil
        } else {
            pausedAt = now
            holdSince = now
        }
    }

    /// Starts a rest of `seconds`, ending on a whole second of the workout clock. The workout clock keeps running.
    /// A paused workout resumes first (logging a set means training again).
    mutating func startRest(_ seconds: Double, at now: Date = .now) {
        settle(at: now)
        if pausedAt != nil { togglePause(at: now) }
        let start = startedAt.addingTimeInterval(stoppedSeconds)
        let end = start.addingTimeInterval((now.timeIntervalSince(start) + seconds).rounded(.up))
        restEndsAt = end
        restSeconds = end.timeIntervalSince(now).rounded()
    }

    mutating func addRest(_ seconds: Double, at now: Date = .now) {
        settle(at: now)
        guard let restEndsAt else { return }
        self.restEndsAt = restEndsAt.addingTimeInterval(seconds)
        restSeconds = max(restSeconds, (restRemaining(at: now) ?? 0).rounded())
    }

    /// Skip: the rest ends now.
    mutating func endRest(at now: Date = .now) {
        restEndsAt = nil
    }
}
