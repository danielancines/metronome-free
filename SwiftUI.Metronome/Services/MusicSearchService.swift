//
//  MusicSearchService.swift
//  SwiftUI.Metronome
//
//  Looks songs up in the iTunes Search API (free, no API key) so the
//  repertoire form can fill in a song title and its band in one tap.
//

import Foundation

struct MusicSearchResult: Identifiable, Hashable {
    let id: Int
    let title: String
    let band: String
    let artworkURL: String?
}

enum MusicSearchService {
    private struct Response: Decodable {
        struct Item: Decodable {
            let trackId: Int?
            let trackName: String?
            let artistName: String?
            let artworkUrl100: String?
        }
        let results: [Item]
    }

    /// Searches songs matching `term`. Throws on network/decoding errors and
    /// when the surrounding task is cancelled.
    static func search(_ term: String, limit: Int = 8) async throws -> [MusicSearchResult] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: trimmed),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: String(limit * 2)), // headroom for de-duplication
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        var seen = Set<String>()
        var results: [MusicSearchResult] = []
        for item in decoded.results {
            guard let id = item.trackId,
                  let title = item.trackName, !title.isEmpty,
                  let band = item.artistName, !band.isEmpty else { continue }
            // The same song often appears once per album/compilation.
            let key = "\(title.lowercased())|\(band.lowercased())"
            guard seen.insert(key).inserted else { continue }
            results.append(MusicSearchResult(id: id, title: title, band: band, artworkURL: item.artworkUrl100))
            if results.count == limit { break }
        }
        return results
    }
}
