import Foundation
import AppKit
import CoreServices

/// ~/Downloads 폴더를 FSEvents로 감시, 새 파일이 완성되면 노치를 확장한다.
final class DownloadModule {
    private weak var viewModel: NotchViewModel?

    private let watchDir: URL
    private var lastKnownFiles: Set<String> = []
    private var fsEventStream: FSEventStreamRef?
    private var autoCollapseTimer: Timer?

    /// 브라우저가 다운로드 중에 쓰는 임시 확장자 — 이 확장자는 무시
    private let tempExtensions: Set<String> = [
        "crdownload", "part", "download", "tmp", "dtapart", "opdownload", "partial"
    ]

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        watchDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        lastKnownFiles = existingFiles()
        startFSEvents()
        setupActions()
    }

    deinit {
        stopFSEvents()
        autoCollapseTimer?.invalidate()
    }

    // MARK: - FSEvents

    private func startFSEvents() {
        var ctx = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )

        let cb: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<DownloadModule>.fromOpaque(info)
                .takeUnretainedValue()
                .directoryDidChange()
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault, cb, &ctx,
            [watchDir.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
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

    private func existingFiles() -> Set<String> {
        (try? FileManager.default.contentsOfDirectory(atPath: watchDir.path)).map(Set.init) ?? []
    }

    private func directoryDidChange() {
        let current = existingFiles()
        let added   = current.subtracting(lastKnownFiles)
        lastKnownFiles = current

        // 유효한 신규 파일만 필터링
        let valid = added.filter { name in
            guard !name.hasPrefix(".") else { return false }
            let ext = (name as NSString).pathExtension.lowercased()
            return !tempExtensions.contains(ext)
        }
        guard let newest = valid.sorted().last else { return }

        let fileURL = watchDir.appendingPathComponent(newest)

        // 파일이 실제로 존재하고 디렉토리가 아닌지 확인
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir),
              !isDir.boolValue else { return }

        // 이미 다운로드 알림이 표시 중이면 무시
        if case .download = viewModel?.leftState { return }

        DispatchQueue.main.async { [weak self] in
            self?.didDetectDownload(fileURL)
        }
    }

    // MARK: - Detection

    private func didDetectDownload(_ url: URL) {
        guard let vm = viewModel else { return }
        vm.downloadedFileURL = url
        vm.leftState = .download(filename: url.lastPathComponent)
        vm.expandedPage = 0
        vm.expand()

        autoCollapseTimer?.invalidate()
        autoCollapseTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    private func dismiss() {
        guard let vm = viewModel else { return }
        autoCollapseTimer?.invalidate()
        if case .download = vm.leftState {
            vm.downloadedFileURL = nil
            vm.leftState = .idle
            vm.collapse()
        }
    }

    // MARK: - Actions

    private func setupActions() {
        viewModel?.copyDownloadAction = { [weak self] in
            guard let self, let url = self.viewModel?.downloadedFileURL else { return }
            // Finder Cmd+V 호환: public.file-url + NSFilenamesPboardType 동시 기록
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.declareTypes([.fileURL, NSPasteboard.PasteboardType("NSFilenamesPboardType")], owner: nil)
            pb.setString(url.absoluteString, forType: .fileURL)
            pb.setPropertyList([url.path], forType: NSPasteboard.PasteboardType("NSFilenamesPboardType"))
            self.dismiss()
        }

        viewModel?.keepDownloadAction = { [weak self] in
            // 파일은 이미 Downloads에 있으니 그냥 닫기
            self?.dismiss()
        }

        viewModel?.deleteDownloadAction = { [weak self] in
            guard let self, let url = self.viewModel?.downloadedFileURL else { return }
            try? FileManager.default.removeItem(at: url)
            self.dismiss()
        }
    }
}
