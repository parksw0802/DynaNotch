import SwiftUI

struct NotchOverlayView: View {
    var viewModel: NotchViewModel

    // 노치를 관통하는 단일 pill 너비 (노치 + 양옆 여백)
    private var pillWidth: CGFloat { viewModel.notchWidth + NotchPanel.pillPadding }
    // 확장 시 패널 너비
    private let expandedWidth: CGFloat = NotchPanel.expandedPanelWidth

    private var activeWidth:  CGFloat { viewModel.isExpanded ? expandedWidth : pillWidth }
    private var activeHeight: CGFloat { viewModel.isExpanded ? viewModel.notchHeight + NotchPanel.expandedExtraHeight : viewModel.notchHeight }
    private var bottomRadius: CGFloat { viewModel.isExpanded ? 20 : viewModel.notchHeight / 3 }

    var body: some View {
        VStack(spacing: 0) {
            // 상단 pill 콘텐츠
            HStack {
                leftPillContent.padding(.leading, 16)
                Spacer()
                rightPillContent.padding(.trailing, 16)
            }
            .frame(width: activeWidth, height: viewModel.notchHeight)

            // 확장 콘텐츠 — 수평 페이저 (항상 레이아웃에 존재, opacity로 fade)
            expandedPager
                .frame(width: expandedWidth, height: NotchPanel.expandedExtraHeight)
                .opacity(viewModel.isExpanded ? 1 : 0)
        }
        // 단일 frame이 width·height 동시에 spring 애니메이션 → 하나의 shape로 확장
        .frame(width: activeWidth, height: activeHeight, alignment: .top)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { viewModel.collapse() }
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: bottomRadius,
                bottomTrailingRadius: bottomRadius,
                topTrailingRadius: 0
            )
            .fill(Color.black)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
    }

    // MARK: - Expanded Pager

    private var expandedPager: some View {
        // ZStack 대신 frame(alignment: .leading) 사용
        // → HStack 리딩이 항상 프레임 리딩에 고정돼 page 0이 기본으로 노출됨
        HStack(spacing: 0) {
            // Page 0 — 음악
            HStack(alignment: .center) {
                leftExpandedContent.padding(.leading, 20)
                Spacer()
            }
            .frame(width: expandedWidth)

            // Page 1 — 알림 (Phase 3 구현 예정)
            notificationsPage.frame(width: expandedWidth)

            // Page 2 — 날씨 (Phase 4 구현 예정)
            weatherPage.frame(width: expandedWidth)
        }
        .offset(x: -CGFloat(viewModel.expandedPage) * expandedWidth)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.expandedPage)
        .frame(width: expandedWidth, alignment: .leading)   // 리딩 고정 + 너비 제한
        .clipped()
        .onTapGesture {}    // 탭이 부모 collapse gesture로 전파되지 않도록 소비
        .overlay(alignment: .bottom) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i == viewModel.expandedPage ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 4, height: 4)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.expandedPage)
                }
            }
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var notificationsPage: some View {
        // Phase 3에서 Slack / 카카오톡 알림 구현 예정
        VStack(spacing: 6) {
            Image(systemName: "bell.slash")
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.3))
            Text("알림 없음")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var weatherPage: some View {
        // Phase 4에서 Open-Meteo API 연동 예정
        VStack(spacing: 6) {
            Image(systemName: "cloud")
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.3))
            Text("날씨 준비 중")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Left Pill Content

    @ViewBuilder
    private var leftPillContent: some View {
        switch viewModel.leftState {
        case .idle:
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 6, height: 6)

        case .music:
            if viewModel.musicIsPlaying, let artwork = viewModel.musicArtwork {
                ArtworkView(image: artwork, size: 18)
            } else {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 6, height: 6)
            }

        case .terminal(let running, _):
            Image(systemName: running ? "gear" : "checkmark")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(running ? Color.yellow : Color.green)
                .symbolEffect(.rotate, isActive: running)

        case .screenshot:
            Image(systemName: "camera.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Left Expanded Content

    @ViewBuilder
    private var leftExpandedContent: some View {
        switch viewModel.leftState {
        case .idle:
            VStack(spacing: 6) {
                Image(systemName: "music.note.slash")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.3))
                Text("재생 중인 음악 없음")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .music(let title, let artist):
            HStack(spacing: 10) {
                WaveformView(isPlaying: viewModel.musicIsPlaying)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                    // 재생 컨트롤
                    HStack(spacing: 14) {
                        Button { viewModel.previousAction?() } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)

                        Button { viewModel.skipBackwardAction?() } label: {
                            Image(systemName: "gobackward.5")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)

                        Button { viewModel.playPauseAction?() } label: {
                            Image(systemName: viewModel.musicIsPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 20)
                        }
                        .buttonStyle(.plain)

                        Button { viewModel.skipForwardAction?() } label: {
                            Image(systemName: "goforward.5")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)

                        Button { viewModel.nextAction?() } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
            }

        case .terminal(let running, let success):
            HStack(spacing: 6) {
                Image(systemName: running ? "gear" : (success == true ? "checkmark.circle.fill" : "xmark.circle.fill"))
                    .foregroundStyle(running ? .yellow : (success == true ? Color.green : Color.red))
                Text(running ? "실행 중..." : (success == true ? "완료" : "실패"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
            }

        case .screenshot:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                    Text("스크린샷 저장 위치")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }

                HStack(spacing: 8) {
                    // 클립보드로 복사
                    Button {
                        viewModel.copyScreenshotAction?()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.85))
                            Text("Clipboard")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    // 기본 저장 경로 (com.apple.screencapture 설정값)
                    if let saveDir = viewModel.screenshotSaveDir {
                        screenshotFolderButton(
                            label: saveDir.lastPathComponent,
                            icon: "folder.fill",
                            folder: saveDir
                        )
                    }
                    // 삭제
                    Button {
                        viewModel.deleteScreenshotAction?()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.red.opacity(0.85))
                            Text("Delete")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Screenshot helpers

    private func screenshotFolder(_ dir: FileManager.SearchPathDirectory) -> URL {
        FileManager.default.urls(for: dir, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    @ViewBuilder
    private func screenshotFolderButton(label: String, icon: String, folder: URL) -> some View {
        Button {
            viewModel.saveScreenshotAction?(folder)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.85))
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Right Pill Content

    @ViewBuilder
    private var rightPillContent: some View {
        switch viewModel.rightContent {
        case .weather(let temp):
            HStack(spacing: 4) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.65))
                Text(temp)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
            }

        case .slack(let channel, _):
            HStack(spacing: 4) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
                Text("#\(channel)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

        case .kakao(let sender, _):
            HStack(spacing: 4) {
                Image(systemName: "message.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
                Text(sender)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
    }

}


// MARK: - WaveformView

private struct WaveformView: View {
    var isPlaying: Bool = true

    // (최소 높이 비율, 최대 높이 비율, 사인 주기(초)) — 각 막대마다 다른 리듬
    private let configs: [(min: CGFloat, max: CGFloat, period: Double)] = [
        (0.10, 0.80, 0.56),
        (0.35, 1.00, 0.42),
        (0.05, 0.65, 0.68),
        (0.25, 0.95, 0.36),
        (0.15, 0.85, 0.60),
        (0.40, 1.00, 0.46),
    ]
    private let maxH: CGFloat = 20

    var body: some View {
        // paused: true → timeline의 date가 멈춤 → 막대 위치 고정
        TimelineView(.animation(paused: !isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(configs.indices, id: \.self) { i in
                    let c = configs[i]
                    let ratio = c.min + (c.max - c.min) * (sin(t / c.period * .pi * 2) * 0.5 + 0.5)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white)
                        .frame(width: 3, height: ratio * maxH)
                }
            }
            .frame(height: maxH, alignment: .bottom)
        }
    }
}

// MARK: - ArtworkView

private struct ArtworkView: View {
    let image: NSImage
    var size: CGFloat = 32

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                // CD 중앙 구멍
                Circle()
                    .fill(Color.black)
                    .frame(width: size * 0.22, height: size * 0.22)
            )
            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
    }
}

// MARK: - NSImage color sampling

extension NSImage {
    /// 이미지를 수직으로 나눠 각 영역의 대표 색상 추출. 어두운 앨범아트도 검은 배경에서 선명하게 보정.
    func sampleColors(count: Int = 3) -> [Color] {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return [.white]
        }
        let w = 8, h = 8
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &data, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [.white] }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        return (0..<count).map { strip in
            let rowStart = strip * h / count
            let rowEnd   = (strip + 1) * h / count
            var r = 0, g = 0, b = 0, n = 0
            for row in rowStart..<rowEnd {
                for col in 0..<w {
                    let idx = (row * w + col) * 4
                    r += Int(data[idx]); g += Int(data[idx+1]); b += Int(data[idx+2])
                    n += 1
                }
            }
            let rf = CGFloat(r) / CGFloat(n * 255)
            let gf = CGFloat(g) / CGFloat(n * 255)
            let bf = CGFloat(b) / CGFloat(n * 255)
            let base = NSColor(red: rf, green: gf, blue: bf, alpha: 1)
                .usingColorSpace(.sRGB) ?? NSColor(red: rf, green: gf, blue: bf, alpha: 1)
            var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
            base.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
            return Color(nsColor: NSColor(
                hue: hue,
                saturation: min(sat + 0.25, 1.0),
                brightness: max(bri, 0.75),
                alpha: 1.0
            ))
        }
    }
}

// MARK: - Preview

#Preview("Collapsed – Idle") {
    NotchOverlayView(viewModel: {
        let vm = NotchViewModel(); vm.notchWidth = 162; vm.notchHeight = 37; return vm
    }())
    .frame(width: 560, height: 150)
    .background(Color(white: 0.2))
}

#Preview("Expanded – Music + Weather") {
    let vm = NotchViewModel()
    vm.notchWidth = 162; vm.notchHeight = 37
    vm.isExpanded = true
    vm.leftState = .music(title: "Blinding Lights", artist: "The Weeknd")
    vm.rightContent = .weather(temp: "18°")
    return NotchOverlayView(viewModel: vm)
        .frame(width: 560, height: 160)
        .background(Color(white: 0.2))
}
