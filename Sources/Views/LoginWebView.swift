import SwiftUI
import WebKit

struct LoginWebView: NSViewRepresentable {
    let onSessionKey: (String) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"
        webView.load(URLRequest(url: URL(string: "https://claude.ai/login")!))
        context.coordinator.startCookiePolling(webView: webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSessionKey: onSessionKey)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let onSessionKey: (String) -> Void
        private var timer: Timer?
        private var found = false
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

        // Handle popup windows (Google OAuth opens in a new window)
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Load the popup URL in the same WebView instead of opening a new one
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        deinit {
            timer?.invalidate()
        }
    }
}
