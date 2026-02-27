import AppKit
import SwiftUI
import WebKit

@MainActor
final class BrowserWindowController {
    static let shared = BrowserWindowController()

    private var window: NSWindow?

    func open(url: URL, sessionKey: String, title: String) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SessionBrowserView(url: url, sessionKey: sessionKey)
        let hostingView = NSHostingView(rootView: view)
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.contentView = hostingView
        w.title = title
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = WindowCloseDelegate.shared

        self.window = w

        NSApp.setActivationPolicy(.regular)
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }
}

private final class WindowCloseDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowCloseDelegate()
    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            BrowserWindowController.shared.close()
        }
    }
}

private struct SessionBrowserView: View {
    let url: URL
    let sessionKey: String
    @State private var webViewRef = WebViewRef()

    var body: some View {
        VStack(spacing: 0) {
            BrowserToolbar(webViewRef: webViewRef)
            SessionWebView(url: url, sessionKey: sessionKey, webViewRef: webViewRef)
        }
    }
}

private struct SessionWebView: NSViewRepresentable {
    let url: URL
    let sessionKey: String
    let webViewRef: WebViewRef

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()

        // Inject session cookie via JS before page loads — guarantees it's set
        let cookieScript = WKUserScript(
            source: "document.cookie = 'sessionKey=\(sessionKey); domain=.claude.ai; path=/; secure; SameSite=None';",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(cookieScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.webViewRef = webViewRef
        context.coordinator.targetURL = url
        context.coordinator.startObservingURL(webView: webView)

        Task { @MainActor in
            webViewRef.webView = webView
        }

        // Set cookie in store, then load claude.ai first to establish session
        if let cookie = HTTPCookie(properties: [
            .name: "sessionKey",
            .value: sessionKey,
            .domain: ".claude.ai",
            .path: "/",
            .secure: "TRUE",
        ]) {
            webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
        }

        // Load claude.ai first; coordinator will redirect to target after it loads
        var request = URLRequest(url: URL(string: "https://claude.ai/")!)
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        webView.load(request)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var webViewRef: WebViewRef?
        var targetURL: URL?
        private var urlObservation: NSKeyValueObservation?
        private var didRedirect = false

        func startObservingURL(webView: WKWebView) {
            urlObservation = webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor [weak self] in
                    guard let ref = self?.webViewRef else { return }
                    ref.currentURL = webView.url?.absoluteString ?? ""
                    ref.canGoBack = webView.canGoBack
                    ref.canGoForward = webView.canGoForward
                    ref.isLoading = webView.isLoading
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            updateNavState(webView)
            if !didRedirect, let targetURL {
                didRedirect = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    webView.load(URLRequest(url: targetURL))
                }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            updateNavState(webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            updateNavState(webView)
        }

        private func updateNavState(_ webView: WKWebView) {
            Task { @MainActor [weak self] in
                guard let ref = self?.webViewRef else { return }
                ref.canGoBack = webView.canGoBack
                ref.canGoForward = webView.canGoForward
                ref.isLoading = webView.isLoading
                ref.currentURL = webView.url?.absoluteString ?? ""
            }
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        deinit {
            urlObservation?.invalidate()
        }
    }
}
