import SwiftUI
import WebKit

@Observable
@MainActor
final class WebViewRef {
    var webView: WKWebView?
    var canGoBack = false
    var canGoForward = false
    var isLoading = false
}

struct LoginWebView: NSViewRepresentable {
    let webViewRef: WebViewRef
    let onSessionKey: (String) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        // Hide the broken Google Sign-In button and "Download desktop app"
        let hideGoogleCSS = WKUserScript(
            source: """
            (function() {
                var style = document.createElement('style');
                style.textContent = `
                    #google-signin-btn, [data-testid="google-signin"],
                    div:has(> iframe[src*="accounts.google.com"]),
                    a[href*="download"], button:has(svg path[d*="M18.71"]),
                    div:has(> div > div:first-child > div[style*="Loading"]) { display: none !important; }
                `;
                document.head.appendChild(style);
                new MutationObserver(function() {
                    document.querySelectorAll('div').forEach(function(el) {
                        var text = el.textContent.trim();
                        if (text === 'Loading...' && el.closest('button,a,[role="button"]')) {
                            var container = el.closest('button,a,[role="button"]');
                            if (container) container.style.display = 'none';
                        }
                        if (text === 'Download desktop app') {
                            var btn = el.closest('button,a,[role="button"]');
                            if (btn) btn.style.display = 'none';
                        }
                    });
                }).observe(document.body || document.documentElement, {childList: true, subtree: true});
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(hideGoogleCSS)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1"
        webView.load(URLRequest(url: URL(string: "https://claude.ai/login")!))

        context.coordinator.mainWebView = webView
        context.coordinator.webViewRef = webViewRef
        context.coordinator.startCookiePolling(webView: webView)

        Task { @MainActor in
            webViewRef.webView = webView
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSessionKey: onSessionKey)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let onSessionKey: (String) -> Void
        weak var mainWebView: WKWebView?
        weak var webViewRef: WebViewRef?
        private var timer: Timer?
        private var found = false

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

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            updateNavState(webView)
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
            }
        }

        // MARK: - WKUIDelegate

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
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
