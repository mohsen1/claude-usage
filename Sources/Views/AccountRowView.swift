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
    let onRename: () -> Void
    let onRenew: () -> Void
    let onRetry: () -> Void
    let onSwitchClaudeCode: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: isPrimary ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(isPrimary ? .blue : .gray.opacity(0.5))
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
                    Text(isAuth ? "Session expired" : error)
                        .font(.system(size: 9))
                        .foregroundStyle(isAuth ? .red : .secondary)
                        .underline(isAuth)
                        .onTapGesture { if isAuth { onRenew() } }
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
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
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
            if error != nil {
                Button("Retry") { onRetry() }
            }
            Button("Rename") { onRename() }
            Button("Renew Session") { onRenew() }
            Button("Open Usage in Browser") {
                BrowserWindowController.shared.open(
                    url: URL(string: "https://claude.ai/settings/usage")!,
                    sessionKey: account.sessionKey,
                    title: "Usage — \(account.displayName)"
                )
            }
            Divider()
            Button("Remove Account", role: .destructive) { onRemove() }
        }
    }
}
