import Foundation
import AppKit
import SwiftUI

/// 각 음악 앱이 DistributedNotificationCenter로 보내는 공개 알림을 구독한다.
/// 별도 권한·private API 불필요.
///
/// 지원 앱:
///   Spotify  → com.spotify.client.PlaybackStateChanged
///   Music    → com.apple.Music.playerInfo
final class MusicModule {
    private weak var viewModel: NotchViewModel?
    private enum MusicApp { case spotify, appleMusic }
    private var activeApp: MusicApp = .spotify

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        registerObservers()
        setupActions()
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    // MARK: - Setup

    private func registerObservers() {
        let dnc = DistributedNotificationCenter.default()

        // Spotify
        dnc.addObserver(
            self,
            selector: #selector(spotifyChanged(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )

        // Apple Music
        dnc.addObserver(
            self,
            selector: #selector(musicAppChanged(_:)),
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil
        )
    }

    // MARK: - Handlers

    @objc private func spotifyChanged(_ note: Notification) {
        guard let info = note.userInfo else { return }
        let state  = info["Player State"] as? String ?? ""
        let title  = info["Name"]         as? String ?? ""
        let artist = info["Artist"]       as? String ?? ""
        activeApp = .spotify
        updateState(state: state, title: title, artist: artist)
        if state == "Playing" { fetchSpotifyArtwork() }
    }

    @objc private func musicAppChanged(_ note: Notification) {
        guard let info = note.userInfo else { return }
        let state  = info["Player State"] as? String ?? ""
        let title  = info["Name"]         as? String ?? ""
        let artist = info["Artist"]       as? String ?? ""
        activeApp = .appleMusic
        updateState(state: state, title: title, artist: artist)
        if state == "Playing" { fetchMusicArtwork() }
    }

    // MARK: - State update

    private func updateState(state: String, title: String, artist: String) {
        DispatchQueue.main.async { [weak self] in
            guard let vm = self?.viewModel else { return }
            vm.musicIsPlaying = (state == "Playing")

            switch state {
            case "Playing", "Paused":
                // 재생 중이거나 일시정지: 곡 정보가 있으면 pill에 유지
                if !title.isEmpty {
                    vm.leftState = .music(
                        title: title,
                        artist: artist.isEmpty ? "알 수 없는 아티스트" : artist
                    )
                }
                // title이 비어있으면 기존 상태 유지 (갑작스러운 알림 노이즈 무시)

            default:
                // "Stopped" 또는 앱 종료 → pill 초기화
                vm.leftState = .idle
                vm.musicArtwork = nil
                vm.musicColors = [.white]
            }
        }
    }

    // MARK: - Playback Controls

    private func setupActions() {
        viewModel?.playPauseAction    = { [weak self] in self?.sendCommand("playpause") }
        viewModel?.previousAction     = { [weak self] in self?.sendCommand("previous track") }
        viewModel?.nextAction         = { [weak self] in self?.sendCommand("next track") }
        viewModel?.skipBackwardAction = { [weak self] in self?.seekRelative(-5) }
        viewModel?.skipForwardAction  = { [weak self] in self?.seekRelative(5) }
    }

    private func seekRelative(_ seconds: Int) {
        let appName = activeApp == .spotify ? "Spotify" : "Music"
        DispatchQueue.global(qos: .userInitiated).async {
            let script = NSAppleScript(source: """
                tell application "\(appName)"
                    set player position to (player position + \(seconds))
                end tell
            """)
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
        }
    }

    private func sendCommand(_ command: String) {
        let appName = activeApp == .spotify ? "Spotify" : "Music"
        DispatchQueue.global(qos: .userInitiated).async {
            let script = NSAppleScript(source: "tell application \"\(appName)\" to \(command)")
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
        }
    }

    // MARK: - Artwork

    /// Spotify: AppleScript으로 artwork url 가져온 뒤 다운로드
    private func fetchSpotifyArtwork() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let script = NSAppleScript(source: """
                tell application "Spotify"
                    if player state is playing then
                        return artwork url of current track
                    end if
                end tell
            """)
            var error: NSDictionary?
            guard let urlString = script?.executeAndReturnError(&error).stringValue,
                  let url = URL(string: urlString),
                  let data = try? Data(contentsOf: url),
                  let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.viewModel?.musicArtwork = image
                self?.viewModel?.musicColors = image.sampleColors()
            }
        }
    }

    /// Apple Music: AppleScript으로 artwork data 가져오기
    private func fetchMusicArtwork() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let script = NSAppleScript(source: """
                tell application "Music"
                    if player state is playing then
                        set art to data of artwork 1 of current track
                        return art
                    end if
                end tell
            """)
            var error: NSDictionary?
            let result = script?.executeAndReturnError(&error)
            guard let data = result?.data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.viewModel?.musicArtwork = image
                self?.viewModel?.musicColors = image.sampleColors()
            }
        }
    }
}
