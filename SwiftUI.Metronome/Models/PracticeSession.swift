//
//  PracticeSession.swift
//  SwiftUI.Metronome
//

import Foundation

struct PracticeSession: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    let bpm: Int
    let beatsPerMeasure: Int
    let subdivision: Subdivision
    let usedSpeedTrainer: Bool

    init(
        id: UUID = UUID(),
        date: Date,
        duration: TimeInterval,
        bpm: Int,
        beatsPerMeasure: Int,
        subdivision: Subdivision,
        usedSpeedTrainer: Bool
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.bpm = bpm
        self.beatsPerMeasure = beatsPerMeasure
        self.subdivision = subdivision
        self.usedSpeedTrainer = usedSpeedTrainer
    }
}
