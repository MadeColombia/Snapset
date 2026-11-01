import SwiftUI

/// Workout time without pauses: counts on its own while running, frozen while paused.
struct ElapsedTime: View {
    let startedAt: Date
    let pausedAt: Date?
    let pausedSeconds: Double

    var body: some View {
        let start = startedAt.addingTimeInterval(pausedSeconds)
        if let pausedAt {
            let seconds = max(0, Int(pausedAt.timeIntervalSince(start)))
            // Same look as the running timer: 5:12, then 1:05:12.
            Text(Duration.seconds(seconds), format: .time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
        } else {
            Text(timerInterval: start...Date.distantFuture, countsDown: false)
        }
    }
}
