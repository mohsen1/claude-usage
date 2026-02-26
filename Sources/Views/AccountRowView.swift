import SwiftUI

struct AccountRowView: View {
    let account: Account
    let usage: UsageData?
    let error: String?
    let isPrimary: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isPrimary ? Color.blue : Color.clear)
                        .overlay(
                            Circle().stroke(isPrimary ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .frame(width: 7, height: 7)
                    Text(account.displayName)
                        .font(.caption)
                        .fontWeight(isPrimary ? .semibold : .regular)
                        .lineLimit(1)
                    Spacer()
                    if let error {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                if let usage {
                    UsageBarView(
                        label: "Session",
                        percentage: usage.sessionPercentage,
                        resetTime: usage.fiveHour?.timeUntilReset
                    )
                    UsageBarView(
                        label: "Weekly",
                        percentage: usage.weeklyPercentage,
                        resetTime: usage.sevenDay?.timeUntilReset
                    )
                } else if error == nil {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 2)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
