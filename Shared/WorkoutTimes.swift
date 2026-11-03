import Foundation

/// The workout's two clocks, as plain values shared by the app, the widget and the tests.
///
/// The workout clock counts training time only: it stands still during a rest and during a pause.
/// The rest clock counts down on its own. When a rest runs out, the workout clock picks up again by itself,
/// so nothing has to update it at that moment (the Live Activity may be asleep).
/// A rest starts on a whole second of the workout clock, so the two clocks always change digits together.
struct WorkoutTimes: Codable, Hashable {
    var startedAt: Date
    /// Closed stops (pauses and rests), left out of the workout time.
    var stoppedSeconds: Double = 0
    /// The workout clock has stood still since then, for a rest or a pause. Nil while it runs.
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

    /// A rest that ran out while not paused: the clock started again at `restEndsAt`.
    private func restOver(at now: Date) -> Bool {
        guard pausedAt == nil, let restEndsAt else { return false }
        return restEndsAt <= now
    }

    /// When a running workout clock read 0:00 (for a self-updating timer text); nil while it stands still at `now`.
    func runningSince(at now: Date = .now) -> Date? {
        guard let holdSince else { return startedAt.addingTimeInterval(stoppedSeconds) }
        guard restOver(at: now), let restEndsAt else { return nil }
        return startedAt.addingTimeInterval(stoppedSeconds + restEndsAt.timeIntervalSince(holdSince))
    }

    /// Workout time at `now`, without pauses and rests.
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

    /// Folds a rest that ran out before `now` into the stopped time.
    mutating func settle(at now: Date = .now) {
        guard restOver(at: now), let restEndsAt, let holdSince else { return }
        stoppedSeconds += restEndsAt.timeIntervalSince(holdSince)
        self.holdSince = nil
        self.restEndsAt = nil
    }

    mutating func togglePause(at now: Date = .now) {
        settle(at: now)
        if let pausedAt {
            let paused = now.timeIntervalSince(pausedAt)
            self.pausedAt = nil
            if let restEndsAt {
                // Still resting: the rest keeps what it had left, and the workout clock keeps standing still.
                self.restEndsAt = restEndsAt.addingTimeInterval(paused)
            } else if let holdSince {
                stoppedSeconds += now.timeIntervalSince(holdSince)
                self.holdSince = nil
            }
        } else {
            pausedAt = now
            if holdSince == nil { holdSince = now }
        }
    }

    /// Starts a rest of `seconds`: the workout clock stops on the second it shows, and the rest ends on a whole
    /// second of it. A paused workout resumes first (logging a set means training again).
    mutating func startRest(_ seconds: Double, at now: Date = .now) {
        settle(at: now)
        if pausedAt != nil { togglePause(at: now) }
        if holdSince == nil {
            let start = startedAt.addingTimeInterval(stoppedSeconds)
            holdSince = start.addingTimeInterval(now.timeIntervalSince(start).rounded(.down))
        }
        let hold = holdSince!
        let end = hold.addingTimeInterval((now.timeIntervalSince(hold) + seconds).rounded(.up))
        restEndsAt = end
        restSeconds = end.timeIntervalSince(now).rounded()
    }

    mutating func addRest(_ seconds: Double, at now: Date = .now) {
        settle(at: now)
        guard let restEndsAt else { return }
        self.restEndsAt = restEndsAt.addingTimeInterval(seconds)
        restSeconds = max(restSeconds, (restRemaining(at: now) ?? 0).rounded())
    }

    /// Skip: the rest ends now and the workout clock runs again (unless the workout is paused).
    mutating func endRest(at now: Date = .now) {
        settle(at: now)
        guard restEndsAt != nil else { return }
        restEndsAt = nil
        if pausedAt == nil, let holdSince {
            stoppedSeconds += now.timeIntervalSince(holdSince)
            self.holdSince = nil
        }
    }
}
