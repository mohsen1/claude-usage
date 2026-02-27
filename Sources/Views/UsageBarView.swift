import SwiftUI

struct UsageBarView: View {
    let label: String
    let percentage: Int
    let resetTime: String?

    private var barColor: Color {
        switch percentage {
        case 0..<70: .blue
        case 70..<90: .orange
        default: .red
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
                .frame(width: 44, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(0, geo.size.width * CGFloat(percentage) / 100))
                }
            }
            .frame(height: 5)
            Text("\(percentage)%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
            if let resetTime {
                Text(resetTime)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.quaternary)
                    .frame(width: 22, alignment: .trailing)
            } else {
                Spacer().frame(width: 22)
            }
        }
        .frame(height: 14)
    }
}
