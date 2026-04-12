import AppKit
import SwiftUI

final class NotchWindowController: NSWindowController {
    private let viewModel = NotchViewModel()
    private var monitors: [Any] = []
    private var lastClickDate: Date = .distantPast
    private var musicModule: MusicModule?
    private var screenshotModule: ScreenshotModule?

    // 스크롤 페이지 전환 상태
    private var scrollAccumX: CGFloat = 0
    private var didSwitchPageThisGesture = false

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
        screenshotModule = ScreenshotModule(viewModel: viewModel)
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        monitors.forEach { NSEvent.removeMonitor($0) }
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

    // MARK: - Event monitors

    private func setupClickMonitor() {
        // 클릭: 축소 상태는 global, 확장 상태는 SwiftUI onTapGesture가 처리
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] _ in
            self?.onMouseDown()
        }) { monitors.append(m) }

        // 스크롤: 볼륨(세로) + 페이지 전환(가로)
        // 축소 상태(global) + 확장 상태(local) 모두 대응
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] event in
            self?.handleScroll(event)
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] event in
            self?.handleScroll(event); return event
        }) { monitors.append(m) }
    }

    // MARK: - Click

    private func onMouseDown() {
        let now = Date()
        guard now.timeIntervalSince(lastClickDate) > 0.3 else { return }
        lastClickDate = now

        let loc = NSEvent.mouseLocation
        if viewModel.isExpanded {
            if !expandedScreenRect.contains(loc) { viewModel.collapse() }
        } else {
            if pillScreenRect.contains(loc) { viewModel.expand() }
        }
    }

    // MARK: - Scroll (볼륨 + 페이지)

    private func handleScroll(_ event: NSEvent) {
        let loc = NSEvent.mouseLocation
        let inRange = viewModel.isExpanded
            ? expandedScreenRect.contains(loc)
            : pillScreenRect.contains(loc)
        guard inRange else { return }

        // 관성 스크롤(손 뗀 후 감속) 무시
        guard event.momentumPhase == [] else { return }

        let dx = event.scrollingDeltaX
        let dy = event.scrollingDeltaY

        // 제스처 시작 시 상태 리셋
        if event.phase == .began {
            scrollAccumX = 0
            didSwitchPageThisGesture = false
        }

        // 세로 스크롤 → 볼륨 (위로 = 증가, dy 부호 반전)
        if abs(dy) >= abs(dx) {
            VolumeController.setVolume(VolumeController.getVolume() - Float(dy) * 0.004)
            return
        }

        // 가로 스크롤 → 페이지 전환 (확장 상태, 한 제스처당 1회만)
        guard viewModel.isExpanded, !didSwitchPageThisGesture else { return }
        scrollAccumX += dx

        if scrollAccumX < -60 {
            viewModel.expandedPage = min(viewModel.expandedPage + 1, 2)
            scrollAccumX = 0
            didSwitchPageThisGesture = true
        } else if scrollAccumX > 60 {
            viewModel.expandedPage = max(viewModel.expandedPage - 1, 0)
            scrollAccumX = 0
            didSwitchPageThisGesture = true
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
