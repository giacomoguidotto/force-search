import AppKit

struct DuckDuckGoSearchProvider: SearchProvider {
    let id = "duckduckgo"
    let name = "DuckDuckGo"
    let iconSymbolName = "shield.lefthalf.filled"

    func searchURL(for query: String) -> URL? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "https://duckduckgo.com/?q=\(encoded)")
    }

    var injectedCSS: String? {
        """
        /* Clean up DuckDuckGo for embedded display */
        .header__form, .header--aside, .js-search-filters,
        .nav-header { display: none !important; }
        body { padding-top: 0 !important; }
        .results--main { margin-top: 8px !important; }
        """
    }
}
