import Foundation
import SwiftUI

@Observable
@MainActor
final class AccountStore {
    var accounts: [Account] = []
    var usageByAccount: [UUID: UsageData] = [:]
    var primaryAccountId: UUID?
    var isLoading = false
    var errors: [UUID: String] = [:]
    var claudeCodeSwitching: UUID?
    var claudeCodeAccountId: UUID?
    var claudeCodeError: String?

    private var pollTask: Task<Void, Never>?
    private let api = UsageAPIService.shared
    private let pollInterval: TimeInterval = 60

    var primaryUsage: UsageData? {
        guard let id = primaryAccountId else { return nil }
        return usageByAccount[id]
    }

    var menuBarText: String {
        guard let usage = primaryUsage else { return "—%" }
        return "\(usage.sessionPercentage)%"
    }

    func load() {
        accounts = KeychainService.loadAccounts()
        primaryAccountId = accounts.first?.id
        if !accounts.isEmpty {
            startPolling()
        }
    }

    func addAccount(_ account: Account) {
        accounts.append(account)
        if primaryAccountId == nil {
            primaryAccountId = account.id
        }
        save()
        startPolling()
    }

    func removeAccount(_ account: Account) {
        accounts.removeAll { $0.id == account.id }
        usageByAccount.removeValue(forKey: account.id)
        errors.removeValue(forKey: account.id)
        if primaryAccountId == account.id {
            primaryAccountId = accounts.first?.id
        }
        save()
        if accounts.isEmpty {
            stopPolling()
        }
    }

    func setPrimary(_ account: Account) {
        primaryAccountId = account.id
    }

    func updateSessionKey(for accountId: UUID, newKey: String) {
        guard let index = accounts.firstIndex(where: { $0.id == accountId }) else { return }
        accounts[index].sessionKey = newKey
        errors.removeValue(forKey: accountId)
        save()
        Task { await refreshAll() }
    }

    func renewSession(for account: Account) {
        LoginWindowController.shared.showRenew(account: account) { [weak self] newKey in
            self?.updateSessionKey(for: account.id, newKey: newKey)
        }
    }

    func refreshAll() async {
        isLoading = true
        defer { isLoading = false }
        await withTaskGroup(of: Void.self) { group in
            for account in accounts {
                group.addTask { [api] in
                    do {
                        let usage = try await api.fetchUsage(
                            sessionKey: account.sessionKey,
                            orgId: account.organizationId
                        )
                        await MainActor.run {
                            self.usageByAccount[account.id] = usage
                            self.errors.removeValue(forKey: account.id)
                        }
                    } catch {
                        await MainActor.run {
                            self.errors[account.id] = error.localizedDescription
                        }
                    }
                }
            }
        }
    }

    func startPolling() {
        stopPolling()
        pollTask = Task {
            await refreshAll()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(pollInterval))
                guard !Task.isCancelled else { break }
                await refreshAll()
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func switchClaudeCode(to account: Account) {
        claudeCodeSwitching = account.id
        claudeCodeError = nil
        Task {
            do {
                try await ClaudeCodeService.shared.switchAccount(
                    sessionKey: account.sessionKey,
                    organizationId: account.organizationId,
                    organizationName: account.displayName
                )
                claudeCodeAccountId = account.id
                claudeCodeSwitching = nil
            } catch {
                claudeCodeError = error.localizedDescription
                claudeCodeSwitching = nil
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    await MainActor.run { self.claudeCodeError = nil }
                }
            }
        }
    }

    private func save() {
        try? KeychainService.saveAccounts(accounts)
    }
}
