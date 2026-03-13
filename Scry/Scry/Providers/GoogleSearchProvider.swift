import AppKit

struct GoogleSearchProvider: SearchProvider {
    let id = "google"
    let name = "Google"
    let iconSymbolName = "magnifyingglass"

    func searchURL(for query: String) -> URL? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "https://www.google.com/search?q=\(encoded)&igu=1")
    }

    var injectedJS: String? {
        """
        // Auto-dismiss Google GDPR cookie consent (consent.google.com redirect)
        (function() {
          function dismissConsent() {
            if (!location.hostname.includes('consent.google')) return false;
            var btn = document.querySelector('form[action*="/save"] button');
            if (btn) { btn.click(); return true; }
            return false;
          }
          if (!dismissConsent()) setTimeout(dismissConsent, 1000);
        })();
        """
    }
}
