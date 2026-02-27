import AppKit
import SwiftUI

@MainActor
final class LoginWindowController {
    static let shared = LoginWindowController()

    private var window: NSWindow?
    private var onAccount: ((Account) -> Void)?
    private var onSessionKey: ((String) -> Void)?

    /// Open login for adding a new account
    func showLogin(onAccount: @escaping (Account) -> Void) {
        self.onAccount = onAccount
        self.onSessionKey = nil
        openWindow(title: "Add Claude Account", mode: .newAccount)
    }

    /// Open login to renew an expired session
    func showRenew(account: Account, onSessionKey: @escaping (String) -> Void) {
        self.onSessionKey = onSessionKey
        self.onAccount = nil
        openWindow(title: "Renew Session — \(account.displayName)", mode: .renewSession)
    }

    private func openWindow(title: String, mode: LoginMode) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let loginView = LoginContainerView(mode: mode) { [weak self] result in
            switch result {
            case .newAccount(let account):
                self?.onAccount?(account)
            case .renewedSession(let sessionKey):
                self?.onSessionKey?(sessionKey)
            }
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
        w.title = title
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
        onSessionKey = nil
        NSApp.setActivationPolicy(.accessory)
    }
}

enum LoginMode {
    case newAccount
    case renewSession
}

enum LoginResult {
    case newAccount(Account)
    case renewedSession(String)
}

private struct LoginContainerView: View {
    let mode: LoginMode
    let onResult: (LoginResult) -> Void
    @State private var status: LoginStatus = .waitingForLogin

    enum LoginStatus {
        case waitingForLogin
        case validating
        case success
        case failed(String)
    }

    @State private var webViewRef = WebViewRef()

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            emailHint
            browserToolbar
            LoginWebView(webViewRef: webViewRef) { sessionKey in
                handleSessionKey(sessionKey)
            }
        }
    }

    private var browserToolbar: some View {
        HStack(spacing: 12) {
            Button {
                webViewRef.webView?.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .disabled(!(webViewRef.canGoBack))

            Button {
                webViewRef.webView?.goForward()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .disabled(!(webViewRef.canGoForward))

            Button {
                webViewRef.webView?.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)

            Spacer()

            if webViewRef.isLoading {
                ProgressView()
                    .controlSize(.mini)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var statusBar: some View {
        HStack {
            switch status {
            case .waitingForLogin:
                Label(
                    mode == .renewSession ? "Log in to renew your session" : "Log in to your Claude account",
                    systemImage: "person.crop.circle"
                )
            case .validating:
                ProgressView().controlSize(.small)
                Text("Validating session...")
            case .success:
                Label(
                    mode == .renewSession ? "Session renewed!" : "Account added!",
                    systemImage: "checkmark.circle.fill"
                )
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

    private var emailHint: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
            Text("Use email login — Google sign-in is not supported")
                .font(.caption2)
        }
        .foregroundStyle(.black.opacity(0.8))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.yellow.opacity(0.7))
    }

    private func handleSessionKey(_ sessionKey: String) {
        status = .validating
        Task {
            do {
                let orgs = try await UsageAPIService.shared.fetchOrganizations(sessionKey: sessionKey)
                guard let org = orgs.first else {
                    status = .failed("No organization found")
                    return
                }

                switch mode {
                case .renewSession:
                    status = .success
                    try? await Task.sleep(for: .seconds(0.5))
                    onResult(.renewedSession(sessionKey))

                case .newAccount:
                    let account = Account(
                        id: UUID(),
                        sessionKey: sessionKey,
                        organizationId: org.uuid,
                        organizationName: org.name,
                        createdAt: Date()
                    )
                    status = .success
                    try? await Task.sleep(for: .seconds(0.5))
                    onResult(.newAccount(account))
                }
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }
}
