import AppKit
import SwiftUI

final class NotchWindowController: NSWindowController {
    private let viewModel = NotchViewModel()
    private var monitors: [Any] = []
    private var lastClickDate: Date = .distantPast
    private var musicModule: MusicModule?
    private var screenshotModule: ScreenshotModule?
    private var weatherModule: WeatherModule?
    private var downloadModule: DownloadModule?

    // 스크롤 페이지 전환 상태
    private var scrollAccumX: CGFloat = 0
    private var didSwitchPageThisGesture = false
    private var lastPageSwitchDate: Date = .distantPast
    // 날씨 페이지: 제스처 시작 시점의 leading edge 여부를 고정
    private var weatherLeadingEdgeAtGestureStart = false
    // 볼륨 존 너비 (expandedScreenRect 기준 우측 끝에서 이 너비만큼)
    private let volumeZoneWidth: CGFloat = 95
    private var volumeSyncTimer: Timer?

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
        setupScrollViewObservers()
        observeExpansion()
        musicModule = MusicModule(viewModel: viewModel)
        screenshotModule = ScreenshotModule(viewModel: viewModel)
        weatherModule = WeatherModule(viewModel: viewModel)
        downloadModule = DownloadModule(viewModel: viewModel)

        // 볼륨 초기값 + 주기적 동기 (외부 변경 반영)
        viewModel.currentVolume = VolumeController.getVolume()
        volumeSyncTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.viewModel.currentVolume = VolumeController.getVolume()
        }
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        monitors.forEach { NSEvent.removeMonitor($0) }
        volumeSyncTimer?.invalidate()
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

    // MARK: - NSScrollView leading-edge tracking

    private func setupScrollViewObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(weatherScrollWillBegin(_:)),
            name: NSScrollView.willStartLiveScrollNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(weatherScrollDidScroll(_:)),
            name: NSScrollView.didLiveScrollNotification,
            object: nil
        )
    }

    /// 날씨 가로 스크롤뷰인지 판단 — 콘텐츠 너비가 뷰 너비보다 충분히 커야 함
    private func isWeatherScrollView(_ scrollView: NSScrollView) -> Bool {
        guard let docView = scrollView.documentView else { return false }
        return docView.frame.width > scrollView.bounds.width + 10
    }

    @objc private func weatherScrollWillBegin(_ notification: Notification) {
        guard let sv = notification.object as? NSScrollView,
              isWeatherScrollView(sv) else { return }
        // 제스처 시작 시점의 스크롤 위치로 leading edge 여부 결정
        weatherLeadingEdgeAtGestureStart = sv.documentVisibleRect.origin.x <= 5
    }

    @objc private func weatherScrollDidScroll(_ notification: Notification) {
        guard let sv = notification.object as? NSScrollView,
              isWeatherScrollView(sv) else { return }
        viewModel.weatherScrollAtLeadingEdge = sv.documentVisibleRect.origin.x <= 5
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

        // 제스처 시작 시 상태 리셋 (weatherLeadingEdgeAtGestureStart는 NSScrollView 알림이 설정)
        if event.phase == .began {
            scrollAccumX = 0
            didSwitchPageThisGesture = false
        }

        // 세로 스크롤 → 볼륨 (음악 탭 볼륨 존 전용)
        if abs(dy) >= abs(dx) {
            if viewModel.isExpanded && viewModel.expandedPage == 0 && volumeZoneScreenRect.contains(loc) {
                let newVol = VolumeController.getVolume() - Float(dy) * 0.004
                VolumeController.setVolume(newVol)
                viewModel.currentVolume = max(0, min(1, newVol))
            }
            return
        }

        // 가로 스크롤 → 페이지 전환 (확장 상태, 한 제스처당 1회 + 0.6초 쿨다운)
        guard viewModel.isExpanded,
              !didSwitchPageThisGesture,
              Date().timeIntervalSince(lastPageSwitchDate) > 0.6 else { return }

        scrollAccumX += dx

        if scrollAccumX < -80 {
            viewModel.expandedPage = min(viewModel.expandedPage + 1, 2)
            scrollAccumX = 0
            didSwitchPageThisGesture = true
            lastPageSwitchDate = Date()
        } else if scrollAccumX > 80 {
            // 날씨 페이지(2): 제스처가 왼쪽 끝에서 시작했을 때만 전환 허용
            if viewModel.expandedPage == 2 && !weatherLeadingEdgeAtGestureStart {
                scrollAccumX = 0  // 무시 — 이 제스처로는 절대 전환 안 함
            } else {
                viewModel.expandedPage = max(viewModel.expandedPage - 1, 0)
                scrollAccumX = 0
                didSwitchPageThisGesture = true
                lastPageSwitchDate = Date()
            }
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

    /// 음악 탭(page 0) 볼륨 존 — expandedScreenRect 우측 끝 volumeZoneWidth 픽셀
    private var volumeZoneScreenRect: NSRect {
        let rect = expandedScreenRect
        return NSRect(x: rect.maxX - volumeZoneWidth,
                      y: rect.minY,
                      width: volumeZoneWidth,
                      height: rect.height)
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
