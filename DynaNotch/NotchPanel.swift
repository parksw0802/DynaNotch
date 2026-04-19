import AppKit

class NotchPanel: NSPanel {
    private(set) var notchWidth: CGFloat = 162
    private(set) var notchHeight: CGFloat = 37

    // Window dimensions
    static let expandedExtraHeight: CGFloat = 110
    static let overlayWidth: CGFloat = 560
    static let pillPadding: CGFloat = 110       // pillWidth = notchWidth + pillPadding
    static let expandedPanelWidth: CGFloat = 480

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: NotchPanel.overlayWidth,
                                height: 37 + NotchPanel.expandedExtraHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Reads notch geometry from the main screen and repositions the panel.
    func positionAtNotch() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        // Notch height (safeAreaInsets.top is 0 on non-notch screens)
        notchHeight = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 37

        // Horizontal notch bounds
        var notchMidX = screenFrame.midX
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            notchWidth = right.minX - left.maxX
            notchMidX = (left.maxX + right.minX) / 2
        }

        let windowHeight = notchHeight + NotchPanel.expandedExtraHeight
        let windowFrame = NSRect(
            x: notchMidX - NotchPanel.overlayWidth / 2,
            y: screenFrame.maxY - windowHeight,
            width: NotchPanel.overlayWidth,
            height: windowHeight
        )
        setFrame(windowFrame, display: true)
    }
}
