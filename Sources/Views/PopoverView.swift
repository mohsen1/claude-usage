import SwiftUI
import AppKit

struct PopoverView: View {
    @Bindable var store: AccountStore
    @State private var showingLogin = false

    var body: some View {
        VStack(spacing: 0) {
            if store.accounts.isEmpty {
                emptyState
            } else {
                accountList
            }
            Divider()
            footer
        }
        .frame(width: 280)
    }

    private var accountList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(store.accounts) { account in
                    AccountRowView(
                        account: account,
                        usage: store.usageByAccount[account.id],
                        error: store.errors[account.id],
                        isPrimary: store.primaryAccountId == account.id,
                        isClaudeCodeAccount: store.claudeCodeAccountId == account.id,
                        isClaudeCodeSwitching: store.claudeCodeSwitching == account.id,
                        onTap: { store.setPrimary(account) },
                        onRemove: { showRemoveAlert(for: account) },
                        onRename: { showRenameAlert(for: account) },
                        onRenew: { store.renewSession(for: account) },
                        onSwitchClaudeCode: { store.switchClaudeCode(to: account) }
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.04))
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 420)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No accounts")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Add a Claude account to get started.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var footer: some View {
        HStack {
            Button("Add Account") {
                LoginWindowController.shared.showLogin { account in
                    store.addAccount(account)
                }
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func showRemoveAlert(for account: Account) {
        let alert = NSAlert()
        alert.messageText = "Remove Account"
        alert.informativeText = "Remove \(account.displayName)? You'll need to log in again to re-add it."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true

        if alert.runModal() == .alertFirstButtonReturn {
            store.removeAccount(account)
        }
    }

    private func showRenameAlert(for account: Account) {
        let alert = NSAlert()
        alert.messageText = "Rename Account"
        alert.informativeText = "Enter a display name. Leave empty to use the organization name."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = account.alias ?? account.displayName
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            store.renameAccount(account, alias: textField.stringValue)
        }
    }
}
