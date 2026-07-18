import Foundation
import UserNotifications

enum NotificationService {
    static func requestAuthIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    static func postAnalysisReady() async {
        let content = UNMutableNotificationContent()
        content.title = "MeetingBrief"
        content.body = "Analyse prête — clique l'icône pour voir"
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "meetingbrief.analysisReady",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(req)
    }
}
