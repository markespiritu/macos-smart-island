import AppKit
import ServiceManagement

/// Wraps SMAppService so the menu can toggle launch at login.
@MainActor
final class LoginItemModel: ObservableObject {
    @Published private(set) var isEnabled = SMAppService.mainApp.status == .enabled

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("SmartIsland: could not change launch at login: \(error)")
        }
        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
