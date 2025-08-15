import Foundation
import SwiftUI

@MainActor
public class PaginatedViewModel<T: Decodable & Identifiable>: ObservableObject {
    @Published var items: [T] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var currentPage = 1
    private var canLoadMorePages = true
    private let pageSize = 20
    private let baseUrl: String
    private let extract: (Data) throws -> [T]

    private let cacheDirectory: URL

    public init(baseUrl: String, extract: @escaping (Data) throws -> [T]) {
        self.baseUrl = baseUrl
        self.extract = extract

        // Create a cache directory in the user's document directory
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.cacheDirectory = documentsDirectory.appendingPathComponent("PaginatedCache")

        // Ensure cache directory exists
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        // Initial data load
        Task {
            await loadMore()
        }
        refresh()
    }

    public func loadMore() async {
        await loadData(url: createURL())
    }

    public func search(query: String) async {
        reset()
        await loadData(url: createSearchURL(query: query))
    }
    
    public func loadAllPages(completion: @escaping () -> Void) {
        Task {
            if items.isEmpty {
                await loadMore()
            }
            while canLoadMorePages && !isLoading {
                await loadMore()
            }
            await MainActor.run {
                completion()
            }
        }
    }


    private func loadData(url: URL?) async {
        guard let url = url, !isLoading && canLoadMorePages else { return }

        isLoading = true
        errorMessage = nil

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(KeyChainUtil.getAccessToken(), forHTTPHeaderField: "Authorization")

        // Check if data is already cached
        if let cachedData = loadCache(for: url) {
            handleData(cachedData)
            self.isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let dataString = String(data: data, encoding: .utf8) {
                PrintUtil.printDebug(data: "Fetched data: \(dataString)")
            }
            // Cache the data for future use
            self.cacheData(data, for: url)
            self.handleData(data)
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func createURL() -> URL? {
        let urlString = "\(baseUrl)?page=\(currentPage)&limit=\(pageSize)"
        return URL(string: urlString)
    }

    private func createSearchURL(query: String) -> URL? {
        let searchBaseUrl = "\(baseUrl)/search"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(searchBaseUrl)?q=\(encodedQuery)&page=\(currentPage)&limit=\(pageSize)"
        return URL(string: urlString)
    }

    private func handleData(_ data: Data) {
        defer { isLoading = false }
        do {
            let newItems = try self.extract(data)
            self.items += newItems
            self.canLoadMorePages = newItems.count == self.pageSize
            self.currentPage += 1
        } catch let decodingError as DecodingError {
            // ... (decoding error handling as before)
            self.errorMessage = "Decoding error: \(decodingError)"
        } catch {
            // ... (unexpected error handling as before)
            self.errorMessage = error.localizedDescription
        }
    }

    private func cacheFileName(for url: URL) -> String {
        return url.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
    }

    private func loadCache(for url: URL) -> Data? {
        let cacheFileURL = cacheDirectory.appendingPathComponent(cacheFileName(for: url))
        return try? Data(contentsOf: cacheFileURL)
    }

    private func cacheData(_ data: Data, for url: URL) {
        let cacheFileURL = cacheDirectory.appendingPathComponent(cacheFileName(for: url))
        try? data.write(to: cacheFileURL)
    }

    private func refresh() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        reset()
    }

    private func clearCache() {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: cacheDirectory.path) {
            do {
                try fileManager.removeItem(at: cacheDirectory)  // Clear the entire cache
                PrintUtil.printDebug(data: "Cache cleared successfully.")
            } catch {
                PrintUtil.printDebug(data: "Error clearing cache: \(error.localizedDescription)")
            }
        }
    }

    public func reset() {
        items = []
        currentPage = 1
        canLoadMorePages = true
    }
}
