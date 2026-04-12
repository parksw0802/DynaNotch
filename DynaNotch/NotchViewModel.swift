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
    }

    enum RightContent {
        case weather(temp: String)
        case slack(channel: String, preview: String)
        case kakao(sender: String, preview: String)
    }

    var leftState: LeftState = .idle
    var musicArtwork: NSImage? = nil
    var musicColors: [Color] = [.white]
    var musicIsPlaying: Bool = false
    var rightContent: RightContent = .weather(temp: "--°")

    // MusicModule이 주입하는 재생 컨트롤 클로저
    var playPauseAction: (() -> Void)?
    var previousAction:  (() -> Void)?
    var nextAction:      (() -> Void)?

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
