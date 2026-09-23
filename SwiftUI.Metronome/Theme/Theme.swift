//
//  Theme.swift
//  SwiftUI.Metronome
//
//  Dark, studio-gear inspired palette.
//

import SwiftUI

enum Theme {
    static let background = Color(red: 0.05, green: 0.055, blue: 0.07)
    static let surface = Color(red: 0.11, green: 0.12, blue: 0.145)
    static let surfaceElevated = Color(red: 0.17, green: 0.18, blue: 0.21)

    static let accent = Color(red: 0.31, green: 0.64, blue: 1.0)
    static let accentSecondary = Color(red: 0.42, green: 0.82, blue: 1.0)
    static let danger = Color(red: 1.0, green: 0.34, blue: 0.34)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)

    static func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .background(surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
