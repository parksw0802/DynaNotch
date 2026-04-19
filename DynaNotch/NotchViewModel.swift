import SwiftUI
import Observation
import AppKit

@Observable
final class NotchViewModel {
    // Layout (set by NotchWindowController after screen geometry is known)
    var notchWidth: CGFloat = 162
    var notchHeight: CGFloat = 37

    // State
    var isExpanded = false

    enum LeftState {
        case idle
        case music(title: String, artist: String)
        case terminal(running: Bool, success: Bool?)
        case screenshot
        case download(filename: String)
    }

    enum RightContent {
        case weather(temp: String)
        case slack(channel: String, preview: String)
        case kakao(sender: String, preview: String)
    }

    var expandedPage: Int = 0
    var expandedPageAnimated: Bool = true   // false 시 페이지 전환 애니메이션 생략
    private var previousExpandedPage: Int = 0

    var leftState: LeftState = .idle
    var musicArtwork: NSImage? = nil
    var musicColors: [Color] = [.white]
    var musicIsPlaying: Bool = false
    var rightContent: RightContent = .weather(temp: "--°")
    var weatherHourly: [HourlyWeather] = []
    var weatherScrollAtLeadingEdge: Bool = true  // ScreenshotModule이 주입, 기본 true
    var currentVolume: Float = 0.5               // VolumeController 값과 동기 (NotchWindowController가 주입)

    // MusicModule이 주입하는 재생 컨트롤 클로저
    var playPauseAction:    (() -> Void)?
    var previousAction:     (() -> Void)?
    var nextAction:         (() -> Void)?
    var skipBackwardAction: (() -> Void)?
    var skipForwardAction:  (() -> Void)?

    // ScreenshotModule
    var screenshotURL: URL? = nil
    var screenshotSaveDir: URL? = nil       // 실제 스크린샷 저장 디렉토리 (ScreenshotModule이 주입)
    var saveScreenshotAction: ((URL) -> Void)? = nil
    var copyScreenshotAction: (() -> Void)? = nil
    var deleteScreenshotAction: (() -> Void)? = nil

    // DownloadModule
    var downloadedFileURL: URL? = nil
    var copyDownloadAction: (() -> Void)? = nil
    var keepDownloadAction: (() -> Void)? = nil
    var deleteDownloadAction: (() -> Void)? = nil

    /// 액션 패널(page 2)로 애니메이션 없이 즉시 이동, 이전 페이지 저장
    func goToActionPage() {
        previousExpandedPage = expandedPage
        expandedPageAnimated = false
        expandedPage = 2
        DispatchQueue.main.async { self.expandedPageAnimated = true }
    }

    /// 액션 패널에서 벗어나 이전 페이지로 애니메이션 없이 복귀
    func dismissActionPage() {
        expandedPageAnimated = false
        expandedPage = previousExpandedPage
        DispatchQueue.main.async { self.expandedPageAnimated = true }
    }

    func expand() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = true
        }
    }

    func collapse() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            isExpanded = false
        }
    }
}
