import AppKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        windowController = NotchWindowController()
        windowController?.window?.orderFrontRegardless()
        registerLoginItem()
    }

    private func registerLoginItem() {
        do {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("[DynaNotch] 로그인 항목 등록 실패: %@", error.localizedDescription)
        }
    }
}
