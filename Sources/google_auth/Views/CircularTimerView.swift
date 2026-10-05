import SwiftUI

public struct CircularTimerView: View {
    public let progress: Double // 1.0 down to 0.0
    public let secondsRemaining: Int
    public var size: CGFloat = 28
    public var lineWidth: CGFloat = 3.0

    public init(progress: Double, secondsRemaining: Int, size: CGFloat = 28, lineWidth: CGFloat = 3.0) {
        self.progress = progress
        self.secondsRemaining = secondsRemaining
        self.size = size
        self.lineWidth = lineWidth
    }

    private var ringColor: Color {
        if secondsRemaining <= 4 {
            return .red
        } else if secondsRemaining <= 8 {
            return .orange
        } else {
            return .accentColor
        }
    }

    public var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(ringColor.opacity(0.18), lineWidth: lineWidth)

            // Animated progress ring
            Circle()
                .trim(from: 0.0, to: CGFloat(max(0.001, min(1.0, progress))))
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)

            // Number inside
            Text("\(secondsRemaining)")
                .font(.system(size: size * 0.38, weight: .bold, design: .monospaced))
                .foregroundColor(ringColor)
        }
        .frame(width: size, height: size)
    }
}
