import AppKit

struct WikipediaProvider: SearchProvider {
    let id = "wikipedia"
    let name = "Wikipedia"
    let iconSymbolName = "book.closed"
    let supportsNativeRendering = true

    func searchURL(for query: String) -> URL? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "https://en.wikipedia.org/w/api.php?action=query&format=json&prop=extracts|pageimages&exintro=1&explaintext=1&piprop=thumbnail&pithumbsize=300&titles=\(encoded)&redirects=1")
    }

    func search(query: String) async throws -> [SearchResult] {
        guard let url = searchURL(for: query) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(WikipediaResponse.self, from: data)

        guard let pages = response.query?.pages else { return [] }

        return pages.compactMap { (_, page) -> SearchResult? in
            guard page.pageid != nil, let title = page.title else { return nil }

            // Skip "missing" pages
            guard page.missing == nil else { return nil }

            let snippet = page.extract ?? "No summary available."
            let imageURL = page.thumbnail?.source.flatMap { URL(string: $0) }
            let articleURL = URL(string: "https://en.wikipedia.org/wiki/\(title.replacingOccurrences(of: " ", with: "_"))")

            return SearchResult(title: title, snippet: snippet, url: articleURL, imageURL: imageURL)
        }
    }
}

// MARK: - Wikipedia API Response

private struct WikipediaResponse: Decodable {
    let query: WikipediaQuery?
}

private struct WikipediaQuery: Decodable {
    let pages: [String: WikipediaPage]?
}

private struct WikipediaPage: Decodable {
    let pageid: Int?
    let title: String?
    let extract: String?
    let thumbnail: WikipediaThumbnail?
    let missing: String?
}

private struct WikipediaThumbnail: Decodable {
    let source: String?
    let width: Int?
    let height: Int?
}
