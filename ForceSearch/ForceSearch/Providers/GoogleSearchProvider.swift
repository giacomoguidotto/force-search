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

    var injectedCSS: String? {
        """
        /* Strip Google header, footer, and search bar for clean embed */
        #searchform, #top_nav, #appbar, .sfbg, #footcnt, footer,
        [role="navigation"], .kp-header, .ΔΡΕ { display: none !important; }
        body { padding-top: 0 !important; }
        #search { padding-top: 8px !important; }
        #center_col { margin-left: 0 !important; padding: 0 12px !important; }
        .g { margin-bottom: 16px !important; }
        """
    }

    var injectedJS: String? {
        """
        // Remove sticky search bar
        document.querySelectorAll('[data-sticky-container]').forEach(el => el.remove());
        """
    }
}
