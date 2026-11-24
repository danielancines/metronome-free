//
//  PracticeSession.swift
//  SwiftUI.Metronome
//

import Foundation

enum SessionKind: String, Codable {
    /// A metronome practice session (tempo-based).
    case practice
    /// A run-through of one or more songs; no tempo is recorded.
    case repertoire
}

struct RepertoireSong: Codable, Equatable, Hashable {
    var title: String
    var band: String
    /// Album cover from the music search, when the song was picked from it.
    var artworkURL: String?

    init(title: String, band: String, artworkURL: String? = nil) {
        self.title = title
        self.band = band
        self.artworkURL = artworkURL
    }
}

struct PracticeSession: Identifiable, Codable, Equatable {
    let id: UUID
    var date: Date
    var duration: TimeInterval
    var bpm: Int
    let beatsPerMeasure: Int
    let subdivision: Subdivision
    let usedSpeedTrainer: Bool
    var kind: SessionKind
    var songs: [RepertoireSong]
    /// Last local modification; decides which copy wins when devices disagree.
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        duration: TimeInterval,
        bpm: Int,
        beatsPerMeasure: Int,
        subdivision: Subdivision,
        usedSpeedTrainer: Bool,
        kind: SessionKind = .practice,
        songs: [RepertoireSong] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.bpm = bpm
        self.beatsPerMeasure = beatsPerMeasure
        self.subdivision = subdivision
        self.usedSpeedTrainer = usedSpeedTrainer
        self.kind = kind
        self.songs = songs
        self.updatedAt = updatedAt
    }

    // Sessions saved before repertoire support have no `kind`/`songs` keys.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        duration = try c.decode(TimeInterval.self, forKey: .duration)
        bpm = try c.decode(Int.self, forKey: .bpm)
        beatsPerMeasure = try c.decode(Int.self, forKey: .beatsPerMeasure)
        subdivision = try c.decode(Subdivision.self, forKey: .subdivision)
        usedSpeedTrainer = try c.decode(Bool.self, forKey: .usedSpeedTrainer)
        kind = try c.decodeIfPresent(SessionKind.self, forKey: .kind) ?? .practice
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? date
        if let structured = try? c.decodeIfPresent([RepertoireSong].self, forKey: .songs) {
            songs = structured
        } else if let titles = try? c.decodeIfPresent([String].self, forKey: .songs) {
            songs = titles.map { RepertoireSong(title: $0, band: "") }
        } else {
            songs = []
        }
    }
}
