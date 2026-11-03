import SwiftUI

/// The workout clock: counts on its own while running (rests included), stands still while paused.
/// No timeline view: the clock only changes state on a pause or resume, which always redraws it.
struct ElapsedTime: View {
    let times: WorkoutTimes

    var body: some View {
        if let since = times.runningSince() {
            Text(timerInterval: since...Date.distantFuture, countsDown: false)
        } else {
            let seconds = Int(times.elapsed())
            // Same look as the running timer: 5:12, then 1:05:12.
            Text(Duration.seconds(seconds), format: .time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
        }
    }
}
