//
//  PracticeHistoryStore.swift
//  SwiftUI.Metronome
//
//  Persists completed practice sessions (no cap) in a local file and keeps
//  them in sync across the user's devices through CloudKit.
//

import Combine
import Foundation

@MainActor
final class PracticeHistoryStore: ObservableObject {
    @Published private(set) var sessions: [PracticeSession] = []

    private let legacyDefaultsKey = "metronome.practiceHistory"
    private let fileURL: URL
    private var cloud: CloudSync?

    init(fileURL: URL = PracticeHistoryStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
        cloud = CloudSync.makeIfAvailable(store: self)
    }

    // MARK: Local changes

    func add(_ session: PracticeSession) {
        var session = session
        session.updatedAt = Date()
        sessions.append(session)
        sessions.sort { $0.date > $1.date }
        save()
        cloud?.queueSave(session.id)
    }

    func update(_ session: PracticeSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        var session = session
        session.updatedAt = Date()
        sessions[index] = session
        sessions.sort { $0.date > $1.date }
        save()
        cloud?.queueSave(session.id)
    }

    func delete(_ session: PracticeSession) {
        sessions.removeAll { $0.id == session.id }
        save()
        cloud?.queueDelete(session.id)
    }

    func clearAll() {
        let ids = sessions.map(\.id)
        sessions.removeAll()
        save()
        ids.forEach { cloud?.queueDelete($0) }
    }

    /// Asks iCloud for changes made on other devices.
    func refreshFromCloud() async {
        await cloud?.refresh()
    }

    // MARK: Changes coming from the cloud

    /// Merges a session received from another device. Returns true when the
    /// local copy is newer and should be pushed back instead.
    @discardableResult
    func applyRemote(_ remote: PracticeSession) -> Bool {
        if let index = sessions.firstIndex(where: { $0.id == remote.id }) {
            if sessions[index].updatedAt > remote.updatedAt { return true }
            sessions[index] = remote
        } else {
            sessions.append(remote)
        }
        sessions.sort { $0.date > $1.date }
        save()
        return false
    }

    func applyRemoteDeletion(_ id: UUID) {
        guard sessions.contains(where: { $0.id == id }) else { return }
        sessions.removeAll { $0.id == id }
        save()
    }

    func session(withID id: UUID) -> PracticeSession? {
        sessions.first { $0.id == id }
    }

    // MARK: Derived

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

    // MARK: Persistence

    nonisolated static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("practiceHistory.json")
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([PracticeSession].self, from: data) {
            sessions = decoded
            return
        }
        // One-time migration from the old UserDefaults storage.
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: legacyDefaultsKey),
           let decoded = try? JSONDecoder().decode([PracticeSession].self, from: data) {
            sessions = decoded
            save()
            defaults.removeObject(forKey: legacyDefaultsKey)
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("PracticeHistoryStore: failed to save — \(error)")
        }
    }
}
