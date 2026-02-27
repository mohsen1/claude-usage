import SwiftUI

struct AccountRowView: View {
    let account: Account
    let usage: UsageData?
    let error: String?
    let isPrimary: Bool
    let isClaudeCodeAccount: Bool
    let isClaudeCodeSwitching: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    let onRenew: () -> Void
    let onSwitchClaudeCode: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isPrimary ? Color.blue : Color.clear)
                        .overlay(
                            Circle().stroke(isPrimary ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .frame(width: 6, height: 6)
                    Text(account.displayName)
                        .font(.system(size: 11, weight: isPrimary ? .semibold : .regular))
                        .lineLimit(1)
                    if isClaudeCodeAccount {
                        Image(systemName: "terminal")
                            .font(.system(size: 8))
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    if let error {
                        let isAuth = error == "Session expired"
                        Button {
                            if isAuth { onRenew() }
                        } label: {
                            Text(isAuth ? "Session expired" : error)
                                .font(.system(size: 9))
                                .foregroundStyle(isAuth ? .red : .secondary)
                                .underline(isAuth)
                        }
                        .buttonStyle(.plain)
                        .disabled(!isAuth)
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
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onSwitchClaudeCode()
            } label: {
                if isClaudeCodeSwitching {
                    Text("Switching...")
                } else if isClaudeCodeAccount {
                    Label("Claude Code (active)", systemImage: "checkmark")
                } else {
                    Label("Switch Claude Code", systemImage: "terminal")
                }
            }
            .disabled(isClaudeCodeSwitching || isClaudeCodeAccount)
            Button("Renew Session") { onRenew() }
            Divider()
            Button("Remove Account", role: .destructive) { showConfirm = true }
        }
        .alert("Remove Account", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) { onRemove() }
        } message: {
            Text("Remove \(account.displayName)? You'll need to log in again to re-add it.")
        }
    }

    @State private var showConfirm = false
}
