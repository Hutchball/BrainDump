//
//  BrainDumpApp.swift
//  BrainDump
//
//  Created by Paul Hutchinson on 09/01/2026.
//

import SwiftUI
import AppIntents
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
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

    @StateObject private var sync = CloudSyncService(store: .shared)
    @Environment(\.scenePhase) private var scenePhase

    init() {
        BrainDumpShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sync)
                .task {
                    guard !ProcessInfo.processInfo.arguments.contains("--living-brain-fixture"), ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
                    await ProStore.shared.refreshEntitlements()
                    sync.start()
                    _ = await CaptureInbox.shared.importPending()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { sync.requestSync() }
                }
        }
    }
}
