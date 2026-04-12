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

            // 확장 콘텐츠 (항상 레이아웃에 존재, opacity로 fade)
            HStack(alignment: .center) {
                leftExpandedContent.padding(.leading, 20)
                Spacer()
                rightExpandedContent.padding(.trailing, 20)
            }
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
            Text("DynaNotch")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))

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
                    HStack(spacing: 20) {
                        Button { viewModel.previousAction?() } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)

                        Button { viewModel.playPauseAction?() } label: {
                            Image(systemName: viewModel.musicIsPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 20)
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
            Text("저장 위치를 선택하세요")
                .font(.system(size: 13))
                .foregroundStyle(.white)
        }
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

    // MARK: - Right Expanded Content

    @ViewBuilder
    private var rightExpandedContent: some View {
        switch viewModel.rightContent {
        case .weather(let temp):
            HStack(spacing: 6) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.65))
                Text(temp)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }

        case .slack(let channel, let preview):
            VStack(alignment: .trailing, spacing: 3) {
                Text("#\(channel)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(preview)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }

        case .kakao(let sender, let preview):
            VStack(alignment: .trailing, spacing: 3) {
                Text(sender)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(preview)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
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
