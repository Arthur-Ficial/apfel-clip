import Foundation
import ServiceManagement

@MainActor
final class SystemLaunchAtLoginController: LaunchAtLoginControlling {
    var isEnabled: Bool {
        guard #available(macOS 13.0, *) else { return false }

        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else { return }

        switch (enabled, SMAppService.mainApp.status) {
        case (true, .enabled), (true, .requiresApproval):
            return
        case (false, .notRegistered), (false, .notFound):
            return
        case (true, _):
            try SMAppService.mainApp.register()
        case (false, _):
            try SMAppService.mainApp.unregister()
        }
    }
}
