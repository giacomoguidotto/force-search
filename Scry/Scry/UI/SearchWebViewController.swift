import AppKit
import WebKit

protocol SearchWebViewDelegate: AnyObject {
    func webViewDidStartLoading()
    func webViewDidFinishLoading()
    func webViewDidFailLoading(error: Error)
    func webViewRequestedExternalNavigation(url: URL)
}

/// WKWebView wrapper for web-based search providers.
final class SearchWebViewController: NSObject {
    weak var delegate: SearchWebViewDelegate?

    let webView: WKWebView
    private var currentProvider: SearchProvider?
    /// Tracks the provider whose scripts are currently installed, to avoid redundant rebuilds.
    private var installedScriptsProviderID: String?

    override init() {
        let config = WKWebViewConfiguration()

        // Use the default persistent data store so consent cookies survive across sessions
        config.websiteDataStore = .default()

        // Use desktop Safari user-agent to avoid mobile layouts and reduce CAPTCHA risk
        config.applicationNameForUserAgent = "Safari/605.1.15"

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15"

        super.init()

        webView.navigationDelegate = self
    }

    func search(query: String, provider: SearchProvider) {
        currentProvider = provider

        guard let url = provider.searchURL(for: query) else { return }

        // Only rebuild user scripts if the provider changed
        if installedScriptsProviderID != provider.id {
            installedScriptsProviderID = provider.id
            let controller = webView.configuration.userContentController
            controller.removeAllUserScripts()

            if let css = provider.injectedCSS {
                let cssScript = """
                var style = document.createElement('style');
                style.textContent = `\(css)`;
                document.head.appendChild(style);
                """
                let userScript = WKUserScript(
                    source: cssScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true
                )
                controller.addUserScript(userScript)
            }

            if let js = provider.injectedJS {
                let userScript = WKUserScript(
                    source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true
                )
                controller.addUserScript(userScript)
            }
        }

        let request = URLRequest(url: url)
        webView.load(request)
    }

    func stopLoading() {
        webView.stopLoading()
    }

    /// Get the current page URL for "Open in Browser" action.
    var currentURL: URL? {
        webView.url
    }
}

extension SearchWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        delegate?.webViewDidStartLoading()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        delegate?.webViewDidFinishLoading()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        delegate?.webViewDidFailLoading(error: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        delegate?.webViewDidFailLoading(error: error)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // If user clicks a link (not the initial search), open in external browser
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url {
            delegate?.webViewRequestedExternalNavigation(url: url)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }
}
