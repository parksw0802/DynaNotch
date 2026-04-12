import AppKit
import SwiftUI

final class NotchWindowController: NSWindowController {
    private let viewModel = NotchViewModel()
    private var monitors: [Any] = []
    private var lastClickDate: Date = .distantPast
    private var musicModule: MusicModule?

    // 드래그 상태
    private var mouseDownLocation: NSPoint? = nil
    private var dragStartVolume: Float = 0
    private var isDragging = false
    private let dragThreshold: CGFloat = 4      // 이 픽셀 이상 이동하면 드래그로 판정
    private let volumeSensitivity: Float = 200  // 드래그 픽셀 당 볼륨 변화 분모

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

    // MARK: - Event monitors (click + drag)

    private func setupClickMonitor() {
        // 축소 상태(ignoresMouseEvents=true): 이벤트가 다른 프로세스로 감 → global monitor
        // 확장 상태(ignoresMouseEvents=false): 이벤트가 우리 프로세스로 감 → local monitor
        addMonitor(global: .leftMouseDown)    { [weak self] in self?.onMouseDown() }
        addMonitor(global: .leftMouseDragged) { [weak self] in self?.onMouseDragged() }
        addMonitor(global: .leftMouseUp)      { [weak self] in self?.onMouseUp() }
        addMonitor(local:  .leftMouseDown)    { [weak self] in self?.onMouseDown() }
        addMonitor(local:  .leftMouseDragged) { [weak self] in self?.onMouseDragged() }
        addMonitor(local:  .leftMouseUp)      { [weak self] in self?.onMouseUp() }
    }

    private func addMonitor(global mask: NSEvent.EventTypeMask, handler: @escaping () -> Void) {
        if let m = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { _ in handler() }) {
            monitors.append(m)
        }
    }

    private func addMonitor(local mask: NSEvent.EventTypeMask, handler: @escaping () -> Void) {
        if let m = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in handler(); return event }) {
            monitors.append(m)
        }
    }

    // MARK: - Mouse event handlers

    private func onMouseDown() {
        let loc = NSEvent.mouseLocation

        if viewModel.isExpanded {
            if expandedScreenRect.contains(loc) {
                // 패널 안 클릭: 드래그 시작 준비 (탭인지 드래그인지는 mouseUp에서 판정)
                mouseDownLocation = loc
                dragStartVolume = VolumeController.getVolume()
                isDragging = false
            } else {
                // 패널 밖 클릭: 즉시 축소
                viewModel.collapse()
            }
        } else {
            // 축소 상태: pill 영역 안에서만 준비
            if pillScreenRect.contains(loc) {
                mouseDownLocation = loc
                dragStartVolume = VolumeController.getVolume()
                isDragging = false
            }
        }
    }

    private func onMouseDragged() {
        guard let start = mouseDownLocation else { return }
        let loc = NSEvent.mouseLocation
        let deltaY = Float(loc.y - start.y)
        guard abs(deltaY) > Float(dragThreshold) else { return }

        isDragging = true
        let newVolume = dragStartVolume + deltaY / volumeSensitivity
        VolumeController.setVolume(newVolume)
    }

    private func onMouseUp() {
        defer {
            mouseDownLocation = nil
            isDragging = false
        }
        guard mouseDownLocation != nil, !isDragging else { return }

        // 드래그 없이 뗐으면 탭으로 처리
        // 확장 상태에서 패널 안 탭은 SwiftUI onTapGesture가 처리 → 여기선 축소 상태만
        guard !viewModel.isExpanded else { return }

        let now = Date()
        guard now.timeIntervalSince(lastClickDate) > 0.3 else { return }
        lastClickDate = now

        let loc = NSEvent.mouseLocation
        if pillScreenRect.contains(loc) { viewModel.expand() }
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
