import AppKit
import SwiftUI

final class NotchWindowController: NSWindowController {
    private let viewModel = NotchViewModel()
    private var globalMonitor: Any?
    private var lastClickDate: Date = .distantPast
    private var musicModule: MusicModule?

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
        observeExpansion()
        musicModule = MusicModule(viewModel: viewModel)
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
    }

    // MARK: - Expansion observation

    /// @Observable 속성 변화를 AppKit 레이어에서 감지 — 재귀 호출로 계속 구독
    private func observeExpansion() {
        withObservationTracking {
            let _ = viewModel.isExpanded
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.updateMousePassthrough()
                self?.observeExpansion()
            }
        }
    }

    private func updateMousePassthrough() {
        // 확장 시: ignoresMouseEvents = false → 버튼 클릭 가능
        // 축소 시: ignoresMouseEvents = true  → 메뉴바 클릭 통과
        window?.ignoresMouseEvents = !viewModel.isExpanded
    }

    // MARK: - Click detection

    private func setupClickMonitor() {
        // 축소 상태: global monitor로 pill 클릭 감지
        // 확장 상태: global monitor로 패널 외부 클릭 → 축소
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.handleClick()
        }
    }

    private func handleClick() {
        let now = Date()
        guard now.timeIntervalSince(lastClickDate) > 0.3 else { return }
        lastClickDate = now

        let loc = NSEvent.mouseLocation
        if viewModel.isExpanded {
            // 확장 중: 패널 밖 클릭이면 축소 (패널 안 클릭은 패널이 직접 처리)
            if !expandedScreenRect.contains(loc) { viewModel.collapse() }
        } else {
            // 축소 중: pill 범위 클릭이면 확장
            if pillScreenRect.contains(loc) { viewModel.expand() }
        }
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

    override func hitTest(_ point: NSPoint) -> NSView? {
        return super.hitTest(point)
    }

    // 비활성 윈도우 상태에서도 첫 번째 클릭을 바로 처리 (기본값 false → 첫 클릭이 활성화에만 쓰임)
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
