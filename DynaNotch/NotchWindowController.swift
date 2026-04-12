import AppKit
import SwiftUI

final class NotchWindowController: NSWindowController {
    private let viewModel = NotchViewModel()
    private var globalMonitor: Any?
    private var lastClickDate: Date = .distantPast

    init() {
        let panel = NotchPanel()
        super.init(window: panel)

        panel.positionAtNotch()

        viewModel.notchWidth  = panel.notchWidth
        viewModel.notchHeight = panel.notchHeight

        let overlayView = NotchOverlayView(viewModel: viewModel)
        let hostingView = NotchHostingView(rootView: overlayView)
        panel.contentView = hostingView

        // 항상 통과 — 클릭 감지는 global monitor(스크린 좌표)로만 처리
        panel.ignoresMouseEvents = true

        setupClickMonitor()
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
    }

    // MARK: - Click detection

    private func setupClickMonitor() {
        // 패널은 항상 ignoresMouseEvents = true이므로 클릭은 항상 global monitor로 감지
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.handleClick()
        }
    }

    private func handleClick() {
        let now = Date()
        guard now.timeIntervalSince(lastClickDate) > 0.3 else { return }
        lastClickDate = now

        let loc = NSEvent.mouseLocation
        let activeRect = viewModel.isExpanded ? expandedScreenRect : pillScreenRect
        guard activeRect.contains(loc) else { return }

        if viewModel.isExpanded { viewModel.collapse() } else { viewModel.expand() }
    }

    private var pillScreenRect: NSRect {
        guard let panel = window else { return .zero }
        let w = viewModel.notchWidth + NotchPanel.pillPadding
        return NSRect(x: panel.frame.midX - w / 2,
                      y: panel.frame.maxY - viewModel.notchHeight,
                      width: w, height: viewModel.notchHeight)
    }

    private var expandedScreenRect: NSRect {
        guard let panel = window else { return .zero }
        let w = NotchPanel.expandedPanelWidth
        let h = viewModel.notchHeight + NotchPanel.expandedExtraHeight
        return NSRect(x: panel.frame.midX - w / 2,
                      y: panel.frame.maxY - h,
                      width: w, height: h)
    }
}

// MARK: - Pass-through hosting view

private final class NotchHostingView: NSHostingView<NotchOverlayView> {

    override var safeAreaInsets: NSEdgeInsets { .init() }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
