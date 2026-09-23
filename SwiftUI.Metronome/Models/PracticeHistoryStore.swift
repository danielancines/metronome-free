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
        if sessions.count > maxStoredSessions {
            sessions.removeLast(sessions.count - maxStoredSessions)
        }
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
