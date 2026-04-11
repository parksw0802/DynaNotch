import AppKit
import SwiftUI

final class NotchWindowController: NSWindowController {
    private let viewModel = NotchViewModel()

    init() {
        let panel = NotchPanel()
        super.init(window: panel)

        // Position first so notch geometry is known
        panel.positionAtNotch()

        // Feed actual geometry into the view model
        viewModel.notchWidth  = panel.notchWidth
        viewModel.notchHeight = panel.notchHeight

        let overlayView = NotchOverlayView(viewModel: viewModel)
        panel.contentView = NotchHostingView(rootView: overlayView)
    }

    required init?(coder: NSCoder) { nil }
}

// MARK: - Pass-through hosting view

/// Passes mouse events through the transparent (non-content) areas of the overlay.
private final class NotchHostingView: NSHostingView<NotchOverlayView> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        // `self` is returned when the cursor is over the transparent background.
        // Returning nil lets the event fall through to windows below.
        return hit === self ? nil : hit
    }
}
