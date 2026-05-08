import SwiftUI

struct LevelBarsView: View {
    let level: Float
    let isMuted: Bool
    let color: Color

    private let barCount = 5
    private let maxBarHeight: CGFloat = 22
    private let minBarHeight: CGFloat = 3
    private let barWidth: CGFloat = 3

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(isMuted ? Color.secondary.opacity(0.35) : color)
                    .frame(width: barWidth, height: barHeight(for: index))
            }
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: level)
        .animation(.easeInOut(duration: 0.25), value: isMuted)
    }

    private func barHeight(for index: Int) -> CGFloat {
        if isMuted { return minBarHeight }
        let threshold = Float(index) / Float(barCount)
        guard level > threshold else { return minBarHeight }
        let stepHeight = (maxBarHeight - minBarHeight) / CGFloat(barCount)
        return minBarHeight + CGFloat(index + 1) * stepHeight
    }
}
