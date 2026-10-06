//
//  BrainDumpApp.swift
//  BrainDump
//
//  Created by Paul Hutchinson on 09/01/2026.
//

import SwiftUI
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let route = response.notification.request.content.userInfo[BrainDumpNotificationManager.routeKey] as? String
        if route == BrainDumpNotificationManager.brainRouteValue {
            BrainDumpNotificationManager.markPendingOpenBrainDump()
        }
        completionHandler()
    }
}

@main
struct BrainDumpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
