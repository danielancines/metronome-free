//
//  Subdivision.swift
//  SwiftUI.Metronome
//

import Foundation

enum Subdivision: Int, CaseIterable, Identifiable, Codable {
    case quarter
    case eighth
    case eighthTriplet
    case sixteenth

    var id: Int { rawValue }

    /// Number of audible ticks per beat.
    var ticksPerBeat: Int {
        switch self {
        case .quarter: return 1
        case .eighth: return 2
        case .eighthTriplet: return 3
        case .sixteenth: return 4
        }
    }

    var shortLabel: String {
        switch self {
        case .quarter: return "♩"
        case .eighth: return "♫"
        case .eighthTriplet: return "3"
        case .sixteenth: return "♬"
        }
    }

    var displayName: String {
        switch self {
        case .quarter: return "Quarter Notes"
        case .eighth: return "Eighth Notes"
        case .eighthTriplet: return "Eighth Triplets"
        case .sixteenth: return "Sixteenth Notes"
        }
    }
}
