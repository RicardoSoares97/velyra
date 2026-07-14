import Foundation

enum TMDBConfiguration {
    static let baseURL = URL(string: "https://api.themoviedb.org/3")!
    static let imageBaseURL = URL(string: "https://image.tmdb.org/t/p")!

    static var readAccessToken: String {
        Bundle.main.object(forInfoDictionaryKey: "TMDB_READ_ACCESS_TOKEN") as? String ?? ""
    }

    static var isConfigured: Bool {
        !readAccessToken.isEmpty && !readAccessToken.contains("$(")
    }

    static func imageURL(path: String?, width: String) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return imageBaseURL
            .appendingPathComponent(width)
            .appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }
}
