import AppKit
import SwiftUI

@main
struct SmartIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings.shared
    @StateObject private var loginItem = LoginItemModel()

    var body: some Scene {
        MenuBarExtra("Smart Island", systemImage: "clock") {
            Toggle("Show Clock", isOn: $settings.isVisible)
            Divider()
            Toggle("24-Hour Time", isOn: $settings.use24Hour)
            Toggle("Show Seconds", isOn: $settings.showSeconds)
            Button("Reset Position") { settings.dragOffset = .zero }
            Divider()
            Toggle("Launch at Login", isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.setEnabled($0) }
            ))
            Divider()
            Button("Quit Smart Island") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: IslandController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // No Dock icon or app menu; the menu bar icon is the only UI besides the island.
        NSApp.setActivationPolicy(.accessory)
        let controller = IslandController(settings: AppSettings.shared)
        controller.update()
        self.controller = controller
    }
}
