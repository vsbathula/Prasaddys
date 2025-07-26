import XCTest
@testable import prasaddys

final class APIClientTests: XCTestCase {
    
    //    let baseURL = URL(string: "https://api.prasaddys.com/api/media")!
    let baseURL = URL(string: "http://127.0.0.1:5225/api/media")!
    let token = ""
    let albumRatingKey = "85472"
    let searchQueryKeyword = "nuvvu"
    
    func testFetchAllAlbums() async throws {
        let apiClient = APIClient(baseURL: baseURL, authorizationToken: token)
        
        do {
            let albums = try await apiClient.fetchAlbums()
            print("Fetched \(albums) albums")
            XCTAssertFalse(albums.albums.isEmpty, "Albums list should not be empty")
        } catch {
            XCTFail("Error fetching albums: \(error)")
        }
    }
    
    func testFetchByAlbumId() async throws {
        let apiClient = APIClient(baseURL: baseURL, authorizationToken: token)
        
        do {
            let albumDetails = try await apiClient.fetchAlbumById(albumRatingKey)
            print("Fetched \(albumDetails) albums")
            XCTAssertFalse(albumDetails.albumTracks.isEmpty, "Albums list should not be empty")
        } catch {
            XCTFail("Error fetching albums: \(error)")
        }
    }
    
    func testSearchAlbums() async throws {
        let apiClient = APIClient(baseURL: baseURL, authorizationToken: token)
        
        do {
            let searchResult = try await apiClient.searchAlbums(query: searchQueryKeyword)
            print("Found albums: \(searchResult.albums.count)")
            print("Found albums: \(searchResult)")
        } catch {
            print("Search failed with error: \(error)")
        }
        
    }
}
