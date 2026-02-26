import SwiftUI

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
            LazyVStack(spacing: 2) {
                ForEach(store.accounts) { account in
                    AccountRowView(
                        account: account,
                        usage: store.usageByAccount[account.id],
                        error: store.errors[account.id],
                        isPrimary: store.primaryAccountId == account.id,
                        onTap: { store.setPrimary(account) }
                    )
                    .padding(.horizontal, 12)
                    if account.id != store.accounts.last?.id {
                        Divider().padding(.horizontal, 12)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 380)
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
                showingLogin = true
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
}
