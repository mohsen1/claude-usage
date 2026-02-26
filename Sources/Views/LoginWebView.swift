import SwiftUI
import WebKit

struct LoginWebView: NSViewRepresentable {
    let onSessionKey: (String) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        // iPhone UA — forces mobile layout, Google serves redirect-based OAuth
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1"
        webView.load(URLRequest(url: URL(string: "https://claude.ai/login")!))
        context.coordinator.mainWebView = webView
        context.coordinator.startCookiePolling(webView: webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSessionKey: onSessionKey)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let onSessionKey: (String) -> Void
        weak var mainWebView: WKWebView?
        private var timer: Timer?
        private var found = false
        private var popupWindow: NSWindow?
        private var popupWebView: WKWebView?

        init(onSessionKey: @escaping (String) -> Void) {
            self.onSessionKey = onSessionKey
        }

        func startCookiePolling(webView: WKWebView) {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self, weak webView] _ in
                guard let self, let webView, !self.found else { return }
                webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                    guard !self.found else { return }
                    if let session = cookies.first(where: { $0.name == "sessionKey" && $0.domain.contains("claude.ai") }) {
                        self.found = true
                        self.timer?.invalidate()
                        self.timer = nil
                        DispatchQueue.main.async {
                            self.closePopup()
                            self.onSessionKey(session.value)
                        }
                    }
                }
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        // MARK: - WKUIDelegate

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            let popup = WKWebView(frame: .zero, configuration: configuration)
            popup.navigationDelegate = self
            popup.uiDelegate = self
            popup.customUserAgent = webView.customUserAgent

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 650),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.contentView = popup
            window.title = "Sign In"
            window.center()
            window.level = .floating
            window.makeKeyAndOrderFront(nil)

            self.popupWindow = window
            self.popupWebView = popup
            return popup
        }

        func webViewDidClose(_ webView: WKWebView) {
            if webView === popupWebView {
                closePopup()
            }
        }

        private func closePopup() {
            popupWindow?.close()
            popupWindow = nil
            popupWebView = nil
        }

        deinit {
            timer?.invalidate()
        }
    }
}
