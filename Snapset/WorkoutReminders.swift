import Foundation
import UserNotifications

/// Local notifications that bring the lifter back to the app: when a rest ends, and when a workout is left
/// running (or paused) with nothing happening. Kept in step with the session on every change, like the Live Activity.
/// Every failure is silent; notifications are optional.
enum WorkoutReminders {
    static let restOverID = "rest-over"
    static let idleID = "workout-idle"

    /// Minutes without a set, pause or resume before the "still training?" nudge.
    static let idleMinutes: Double = 15
    /// A paused workout gets longer before the nudge, since a pause is meant to be a break.
    static let pausedMinutes: Double = 30

    /// iOS shows the permission alert only the first time; later calls return at once.
    static func requestAccess() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    /// What should be scheduled for `session` as it is at `now`; split out so it can be tested without the notification center.
    struct Plan: Equatable {
        var restOver: Date?
        var idle: Date
        var idlePaused: Bool
    }

    static func plan(for session: WorkoutSession, at now: Date = .now) -> Plan? {
        guard session.finishedAt == nil else { return nil }
        if session.pausedAt != nil {
            return Plan(restOver: nil, idle: now.addingTimeInterval(pausedMinutes * 60), idlePaused: true)
        }
        let restOver = session.restEndsAt.flatMap { $0 > now ? $0 : nil }
        // Counted from the end of the rest, so a long rest doesn't eat into the idle time.
        let from = max(now, restOver ?? now)
        return Plan(restOver: restOver, idle: from.addingTimeInterval(idleMinutes * 60), idlePaused: false)
    }

    /// Replaces the pending reminders with the ones `session` needs now. `upNext` is the Live Activity's line,
    /// e.g. "Set 2/3: 60 kg × 8 · Bench Press".
    static func sync(_ session: WorkoutSession, upNext: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [restOverID, idleID])
        guard let plan = plan(for: session) else { return }
        if let restOver = plan.restOver {
            add(restOverID, at: restOver, title: "Rest's over", body: "Up next: \(upNext)")
        }
        if plan.idlePaused {
            add(idleID, at: plan.idle, title: "Your workout is paused",
                body: "Resume when you're ready, or finish it so it's saved.")
        } else {
            add(idleID, at: plan.idle, title: "Still training?",
                body: "Your workout is still running. Log your next set, or finish it so it's saved.")
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restOverID, idleID])
    }

    private static func add(_ id: String, at date: Date, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
