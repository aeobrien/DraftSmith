import Foundation

@Observable
@MainActor
final class RecentDocumentsManager {
    static let shared = RecentDocumentsManager()

    private static let maxRecent = 10
    private static let userDefaultsKey = "DraftSmith.recentDocumentURLs"

    private(set) var recentURLs: [URL] = []

    private init() {
        loadRecent()
    }

    func addDocument(url: URL) {
        // Remove if already present, then prepend
        recentURLs.removeAll { $0 == url }
        recentURLs.insert(url, at: 0)
        if recentURLs.count > Self.maxRecent {
            recentURLs = Array(recentURLs.prefix(Self.maxRecent))
        }
        saveRecent()
    }

    func clearRecent() {
        recentURLs = []
        saveRecent()
    }

    private func loadRecent() {
        guard let bookmarks = UserDefaults.standard.array(forKey: Self.userDefaultsKey) as? [Data] else {
            return
        }
        recentURLs = bookmarks.compactMap { data in
            var isStale = false
            return try? URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &isStale)
        }
    }

    private func saveRecent() {
        let bookmarks = recentURLs.compactMap { url -> Data? in
            try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        UserDefaults.standard.set(bookmarks, forKey: Self.userDefaultsKey)
    }
}
