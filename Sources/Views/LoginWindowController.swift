import AppKit
import SwiftUI

@MainActor
final class LoginWindowController {
    static let shared = LoginWindowController()

    private var window: NSWindow?
    private var onAccount: ((Account) -> Void)?

    func showLogin(onAccount: @escaping (Account) -> Void) {
        self.onAccount = onAccount

        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let loginView = LoginContainerView { [weak self] account in
            self?.onAccount?(account)
            self?.close()
        }

        let hostingView = NSHostingView(rootView: loginView)
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 720),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.contentView = hostingView
        w.title = "Add Claude Account"
        w.center()
        w.isReleasedWhenClosed = false

        self.window = w

        NSApp.setActivationPolicy(.regular)
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
        window = nil
        onAccount = nil
        NSApp.setActivationPolicy(.accessory)
    }
}

private struct LoginContainerView: View {
    let onAccount: (Account) -> Void
    @State private var status: LoginStatus = .waitingForLogin

    enum LoginStatus {
        case waitingForLogin
        case validating
        case success
        case failed(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            LoginWebView { sessionKey in
                validateAndCreate(sessionKey: sessionKey)
            }
        }
    }

    private var statusBar: some View {
        HStack {
            switch status {
            case .waitingForLogin:
                Label("Log in to your Claude account", systemImage: "person.crop.circle")
            case .validating:
                ProgressView().controlSize(.small)
                Text("Validating session...")
            case .success:
                Label("Account added!", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed(let msg):
                Label(msg, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            Spacer()
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func validateAndCreate(sessionKey: String) {
        status = .validating
        Task {
            do {
                let orgs = try await UsageAPIService.shared.fetchOrganizations(sessionKey: sessionKey)
                guard let org = orgs.first else {
                    status = .failed("No organization found")
                    return
                }
                let account = Account(
                    id: UUID(),
                    sessionKey: sessionKey,
                    organizationId: org.uuid,
                    organizationName: org.name,
                    createdAt: Date()
                )
                status = .success
                try? await Task.sleep(for: .seconds(1))
                onAccount(account)
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }
}
