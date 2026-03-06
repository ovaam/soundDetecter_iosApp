//
//  NotificationManager.swift
//  soundDapp
//
//  Запрос разрешения и отправка локальных уведомлений «Кто-то в двери».
//

import UserNotifications
import Foundation

final class NotificationManager {
    static let shared = NotificationManager()

    private let notificationTitle = "Кто-то в двери"
    private let notificationBody = "Обнаружен звонок или стук в дверь."
    private let categoryIdentifier = "DOOR_SOUND"

    private init() {}

    /// Запрашивает разрешение на уведомления.
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        do {
            let granted = try await center.requestAuthorization(options: options)
            return granted
        } catch {
            return false
        }
    }

    /// Отправляет локальное уведомление «Кто-то в двери».
    func sendDoorSoundNotification() {
        let content = UNMutableNotificationContent()
        content.title = notificationTitle
        content.body = notificationBody
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }
}
