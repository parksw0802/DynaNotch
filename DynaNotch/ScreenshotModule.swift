import Foundation
import AppKit
import CoreServices
import SwiftUI

/// 스크린샷 저장 디렉토리를 FSEvents로 감시한다.
/// kqueue(DispatchSource)와 달리 atomic write / 외부 이동으로 생긴 파일도 감지된다.
final class ScreenshotModule {
    private weak var viewModel: NotchViewModel?

    private var watchDir: URL = FileManager.default.homeDirectoryForCurrentUser
    private var lastKnownFiles: Set<String> = []
    private var fsEventStream: FSEventStreamRef?
    private var autoCollapseTimer: Timer?

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        watchDir = screenshotDirectory()
        viewModel.screenshotSaveDir = watchDir
        lastKnownFiles = existingFiles(in: watchDir)
        startFSEvents(watchDir)
        setupActions()
    }

    deinit {
        stopFSEvents()
        autoCollapseTimer?.invalidate()
    }

    // MARK: - Screenshot directory

    private func screenshotDirectory() -> URL {
        // shell을 통해 읽어 UserDefaults 동기화 문제를 피한다
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments  = ["read", "com.apple.screencapture", "location"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError  = Pipe()
        try? task.run()
        task.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !output.isEmpty {
            return URL(fileURLWithPath: (output as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
    }

    private func existingFiles(in dir: URL) -> Set<String> {
        (try? FileManager.default.contentsOfDirectory(atPath: dir.path)).map(Set.init) ?? []
    }

    // MARK: - FSEvents

    private func startFSEvents(_ dir: URL) {
        var ctx = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )

        let cb: FSEventStreamCallback = { _, info, _, eventPaths, _, _ in
            guard let info else { return }
            Unmanaged<ScreenshotModule>.fromOpaque(info)
                .takeUnretainedValue()
                .directoryDidChange()
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            cb,
            &ctx,
            [dir.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,    // 0.3s latency
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents |
                                     kFSEventStreamCreateFlagUseCFTypes |
                                     kFSEventStreamCreateFlagNoDefer)
        ) else { return }

        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
        fsEventStream = stream
    }

    private func stopFSEvents() {
        guard let stream = fsEventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        fsEventStream = nil
    }

    // MARK: - Change handler

    private func directoryDidChange() {
        let current = existingFiles(in: watchDir)
        let added   = current.subtracting(lastKnownFiles)
        lastKnownFiles = current

        let screenshots = added.filter { name in
            let l = name.lowercased()
            return (l.contains("screenshot") || l.contains("스크린샷"))
                && (l.hasSuffix(".png") || l.hasSuffix(".heic") || l.hasSuffix(".jpg"))
        }
        guard let newest = screenshots.sorted().last else { return }
        let url = watchDir.appendingPathComponent(newest)

        DispatchQueue.main.async { [weak self] in self?.didDetectScreenshot(url) }
    }

    // MARK: - Detection

    private func didDetectScreenshot(_ url: URL) {
        guard let vm = viewModel else { return }
        vm.screenshotURL = url
        vm.leftState = .screenshot
        vm.goToActionPage()
        vm.expand()

        autoCollapseTimer?.invalidate()
        autoCollapseTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            self?.autoCollapse()
        }
    }

    private func autoCollapse() {
        guard let vm = viewModel, case .screenshot = vm.leftState else { return }
        dismissScreenshot()
    }

    // MARK: - Actions

    private func setupActions() {
        viewModel?.saveScreenshotAction = { [weak self] destination in
            self?.saveScreenshot(to: destination)
        }
        viewModel?.copyScreenshotAction = { [weak self] in
            self?.copyScreenshotToClipboard()
        }
        viewModel?.deleteScreenshotAction = { [weak self] in
            self?.deleteScreenshot()
        }
    }

    private func dismissScreenshot() {
        guard let vm = viewModel else { return }
        autoCollapseTimer?.invalidate()
        vm.screenshotURL = nil
        vm.leftState = .idle
        vm.dismissActionPage()
        vm.collapse()
    }

    private func saveScreenshot(to destDir: URL) {
        guard let vm = viewModel, let src = vm.screenshotURL else { return }
        let dest = destDir.appendingPathComponent(src.lastPathComponent)
        try? FileManager.default.moveItem(at: src, to: dest)
        dismissScreenshot()
    }

    private func deleteScreenshot() {
        guard let vm = viewModel, let src = vm.screenshotURL else { return }
        try? FileManager.default.removeItem(at: src)
        dismissScreenshot()
    }

    private func copyScreenshotToClipboard() {
        guard let vm = viewModel,
              let src = vm.screenshotURL,
              let image = NSImage(contentsOf: src) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        dismissScreenshot()
    }
}
