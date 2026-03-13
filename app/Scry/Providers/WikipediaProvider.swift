import AppKit

struct WikipediaProvider: SearchProvider {
    let id = "wikipedia"
    let name = "Wikipedia"
    let iconSymbolName = "book.closed"
    let supportsNativeRendering = true

    func searchURL(for query: String) -> URL? {
        var components = URLComponents(string: "https://en.wikipedia.org/w/api.php")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "prop", value: "extracts|pageimages"),
            URLQueryItem(name: "exintro", value: "1"),
            URLQueryItem(name: "explaintext", value: "1"),
            URLQueryItem(name: "piprop", value: "thumbnail"),
            URLQueryItem(name: "pithumbsize", value: "300"),
            URLQueryItem(name: "titles", value: query),
            URLQueryItem(name: "redirects", value: "1"),
        ]
        return components?.url
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
