import SwiftUI
import Combine
import UIKit
import Foundation
import UniformTypeIdentifiers
import QuartzCore
import UserNotifications
import CryptoKit
import Darwin

enum BrainDumpNotificationManager {
    private static let center = UNUserNotificationCenter.current()
    private static let defaults = UserDefaults.standard
    private static let notificationsEnabledKey = "BrainDumpNotificationsEnabled"
    private static let notificationsEnabledAtKey = "BrainDumpNotificationsEnabledAt"
    private static let pendingOpenBrainDumpKey = "PendingOpenBrainDumpFromNotification"
    static let openBrainDumpNotificationName = Notification.Name("OpenBrainDumpFromNotification")
    static let routeKey = "route"
    static let brainRouteValue = "brain_dumps"
    static let nightlyReminderIdentifier = "BrainDumpNightlyReminder"

    static func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                defaults.set(true, forKey: notificationsEnabledKey)
                if defaults.object(forKey: notificationsEnabledAtKey) == nil {
                    defaults.set(Date(), forKey: notificationsEnabledAtKey)
                }
            } else {
                defaults.set(false, forKey: notificationsEnabledKey)
            }
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    static func setNotificationsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: notificationsEnabledKey)
        if enabled {
            if defaults.object(forKey: notificationsEnabledAtKey) == nil {
                defaults.set(Date(), forKey: notificationsEnabledAtKey)
            }
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [nightlyReminderIdentifier])
        }
    }

    static func updateNightlyReminder(unsortedCount: Int, now: Date = Date()) {
        if unsortedCount <= 0 {
            center.removePendingNotificationRequests(withIdentifiers: [nightlyReminderIdentifier])
            return
        }

        guard defaults.bool(forKey: notificationsEnabledKey) else { return }

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                defaults.set(true, forKey: notificationsEnabledKey)
                if defaults.object(forKey: notificationsEnabledAtKey) == nil {
                    defaults.set(now, forKey: notificationsEnabledAtKey)
                }
                let content = UNMutableNotificationContent()
                content.title = "Brain Dump Reminder"
                content.body = reminderBody(for: unsortedCount, now: now)
                content.sound = .default
                content.userInfo = [routeKey: brainRouteValue]

                var dateComponents = DateComponents()
                dateComponents.hour = 20
                dateComponents.minute = 30
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: nightlyReminderIdentifier,
                    content: content,
                    trigger: trigger
                )
                center.removePendingNotificationRequests(withIdentifiers: [nightlyReminderIdentifier])
                center.add(request)
            default:
                center.removePendingNotificationRequests(withIdentifiers: [nightlyReminderIdentifier])
            }
        }
    }

    static func triggerAllDebugNotificationVariants() {
        requestAuthorization { granted in
            guard granted else { return }
            let identifiers = [
                "BrainDumpDebugReminder_1",
                "BrainDumpDebugReminder_2",
                "BrainDumpDebugReminder_3"
            ]
            center.removePendingNotificationRequests(withIdentifiers: identifiers)

            let variants: [(String, TimeInterval)] = [
                ("Sort your Brain Dumps!", 3),
                ("You have 3 Brain Dumps!", 8),
                ("Youve been busy today, you have 8 Brain Dumps!", 13)
            ]

            for (index, variant) in variants.enumerated() {
                let content = UNMutableNotificationContent()
                content.title = "Brain Dump Reminder (Debug)"
                content.body = variant.0
                content.sound = .default
                content.userInfo = [routeKey: brainRouteValue]

                let request = UNNotificationRequest(
                    identifier: identifiers[index],
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: variant.1, repeats: false)
                )
                center.add(request)
            }
        }
    }

    private static func reminderBody(for unsortedCount: Int, now: Date) -> String {
        let enabledAt = defaults.object(forKey: notificationsEnabledAtKey) as? Date ?? now
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: enabledAt)
        let today = calendar.startOfDay(for: now)
        let daysElapsed = calendar.dateComponents([.day], from: startDay, to: today).day ?? 0

        if daysElapsed < 2 {
            return "Sort your Brain Dumps!"
        }
        if unsortedCount < 5 {
            return "You have \(unsortedCount) Brain Dumps!"
        }
        return "Youve been busy today, you have \(unsortedCount) Brain Dumps!"
    }

    static func markPendingOpenBrainDump() {
        defaults.set(true, forKey: pendingOpenBrainDumpKey)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: openBrainDumpNotificationName, object: nil)
        }
    }

    static func consumePendingOpenBrainDump() -> Bool {
        let pending = defaults.bool(forKey: pendingOpenBrainDumpKey)
        if pending {
            defaults.set(false, forKey: pendingOpenBrainDumpKey)
        }
        return pending
    }
}
