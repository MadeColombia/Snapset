import SwiftUI

/// The workout clock: counts on its own while running, stands still during a rest or a pause,
/// and picks up again by itself when a rest runs out.
struct ElapsedTime: View {
    let times: WorkoutTimes

    var body: some View {
        // Re-read every second while standing still, so a rest that runs out restarts the clock without an update.
        TimelineView(.periodic(from: times.tickStart, by: 1)) { timeline in
            if let since = times.runningSince(at: timeline.date) {
                Text(timerInterval: since...Date.distantFuture, countsDown: false)
            } else {
                let seconds = Int(times.elapsed(at: timeline.date))
                // Same look as the running timer: 5:12, then 1:05:12.
                Text(Duration.seconds(seconds), format: .time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
            }
        }
    }
}
