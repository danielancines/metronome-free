//
//  PracticeHistoryStore.swift
//  SwiftUI.Metronome
//
//  Persists completed practice sessions so they survive relaunches.
//

import Combine
import Foundation

@MainActor
final class PracticeHistoryStore: ObservableObject {
    @Published private(set) var sessions: [PracticeSession] = []

    private let defaultsKey = "metronome.practiceHistory"
    private let maxStoredSessions = 300

    init() {
        load()
    }

    func add(_ session: PracticeSession) {
        sessions.insert(session, at: 0)
        // Manually added sessions can be backdated, so keep newest-first
        // ordering before trimming the oldest ones.
        sessions.sort { $0.date > $1.date }
        if sessions.count > maxStoredSessions {
            sessions.removeLast(sessions.count - maxStoredSessions)
        }
        save()
    }

    func update(_ session: PracticeSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[index] = session
        save()
    }

    func delete(_ session: PracticeSession) {
        sessions.removeAll { $0.id == session.id }
        save()
    }

    func clearAll() {
        sessions.removeAll()
        save()
    }

    /// Every band used in a repertoire so far, alphabetical, without duplicates
    /// (case-insensitive) — used to suggest bands when adding songs.
    var knownBands: [String] {
        var seen = Set<String>()
        var bands: [String] = []
        for song in sessions.flatMap(\.songs) {
            let band = song.band.trimmingCharacters(in: .whitespacesAndNewlines)
            if !band.isEmpty, seen.insert(band.lowercased()).inserted {
                bands.append(band)
            }
        }
        return bands.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var totalPracticeTime: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        if let decoded = try? JSONDecoder().decode([PracticeSession].self, from: data) {
            sessions = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
