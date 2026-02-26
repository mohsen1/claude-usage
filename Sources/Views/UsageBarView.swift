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
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(percentage)%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let resetTime {
                    Text(resetTime)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * CGFloat(percentage) / 100)
                }
            }
            .frame(height: 4)
        }
    }
}
