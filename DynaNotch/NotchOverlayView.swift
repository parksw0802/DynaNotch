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
