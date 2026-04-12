import SwiftUI

@main
struct DynaNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button("DynaNotch 종료") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "circle.fill")
                .imageScale(.small)
        }
    }
}
