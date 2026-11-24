//
//  SwiftUI_MetronomeApp.swift
//  SwiftUI.Metronome
//
//  Created by Daniel Ancines on 23/09/26.
//

import SwiftUI

@main
struct SwiftUI_MetronomeApp: App {
    #if os(iOS) || os(visionOS)
    @UIApplicationDelegateAdaptor private var appDelegate: PushRegistrationDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor private var appDelegate: PushRegistrationDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// CloudKit delivers "another device changed something" as silent pushes, which
// requires the app to register for remote notifications.
#if os(iOS) || os(visionOS)
import UIKit
final class PushRegistrationDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }
}
#elseif os(macOS)
import AppKit
final class PushRegistrationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.registerForRemoteNotifications()
    }
}
#endif
