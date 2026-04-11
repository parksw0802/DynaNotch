import SwiftUI

struct NotchOverlayView: View {
    var viewModel: NotchViewModel

    // Pill section width on each side of the notch in expanded state
    private var pillSectionWidth: CGFloat {
        (NotchPanel.overlayWidth - viewModel.notchWidth) / 2
    }

    var body: some View {
        ZStack(alignment: .top) {
            if viewModel.isExpanded {
                expandedView
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                        removal:   .scale(scale: 0.96, anchor: .top).combined(with: .opacity)
                    ))
            } else {
                collapsedView
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                        removal:   .scale(scale: 0.96, anchor: .top).combined(with: .opacity)
                    ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Collapsed

    private var collapsedView: some View {
        HStack(spacing: viewModel.notchWidth) {
            leftPillContent
                .frame(width: 120, height: viewModel.notchHeight)
                .background(Color.black)
                .clipShape(Capsule())

            rightPillContent
                .frame(width: 120, height: viewModel.notchHeight)
                .background(Color.black)
                .clipShape(Capsule())
        }
        .onHover { if $0 { viewModel.expand() } }
    }

    // MARK: - Expanded

    private var expandedView: some View {
        VStack(spacing: 0) {
            // Top row: left section + notch gap + right section
            HStack(spacing: viewModel.notchWidth) {
                leftPillContent
                    .frame(width: pillSectionWidth, height: viewModel.notchHeight)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 16
                        )
                        .fill(Color.black)
                    )

                rightPillContent
                    .frame(width: pillSectionWidth, height: viewModel.notchHeight)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 16
                        )
                        .fill(Color.black)
                    )
            }

            // Content panel — connects the two pill sections at the bottom
            expandedContent
                .frame(width: NotchPanel.overlayWidth, height: NotchPanel.expandedExtraHeight)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 20,
                        bottomTrailingRadius: 20,
                        topTrailingRadius: 0
                    )
                    .fill(Color.black)
                )
        }
        .onHover { if !$0 { viewModel.collapse() } }
    }

    private var expandedContent: some View {
        HStack(alignment: .center) {
            leftExpandedContent
                .padding(.leading, 20)
            Spacer()
            rightExpandedContent
                .padding(.trailing, 20)
        }
    }

    // MARK: - Left Pill Content

    @ViewBuilder
    private var leftPillContent: some View {
        switch viewModel.leftState {
        case .idle:
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 7, height: 7)

        case .music(let title, _):
            HStack(spacing: 5) {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)

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
                .foregroundStyle(.white.opacity(0.35))

        case .music(let title, let artist):
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(artist)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

        case .terminal(let running, let success):
            HStack(spacing: 6) {
                Image(
                    systemName: running
                        ? "gear"
                        : (success == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                )
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
            .padding(.horizontal, 10)

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
            .padding(.horizontal, 10)

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
            .padding(.horizontal, 10)
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

// MARK: - Preview

#Preview("Collapsed – Idle") {
    NotchOverlayView(viewModel: NotchViewModel())
        .frame(width: 560, height: 150)
        .background(Color(white: 0.15))
}

#Preview("Expanded – Music + Weather") {
    let vm = NotchViewModel()
    vm.isExpanded = true
    vm.leftState = .music(title: "Blinding Lights", artist: "The Weeknd")
    vm.rightContent = .weather(temp: "18°")
    return NotchOverlayView(viewModel: vm)
        .frame(width: 560, height: 150)
        .background(Color(white: 0.15))
}
