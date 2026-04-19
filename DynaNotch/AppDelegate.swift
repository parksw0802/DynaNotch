import AppKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NotchWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowController = NotchWindowController()
        windowController?.window?.orderFrontRegardless()
        registerLoginItem()
        setupMenuBarIcon()
    }

    // MARK: - Menu bar icon

    private func setupMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "circle.inset.filled", accessibilityDescription: "DynaNotch")
            button.image?.isTemplate = true  // 다크/라이트 모드 자동 대응
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "DynaNotch", action: nil, keyEquivalent: ""))
        menu.items[0].isEnabled = false
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Login item

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
