//
//  SessionTimerView.swift
//  SwiftUI.Metronome
//

import SwiftUI

struct SessionTimerView: View {
    let elapsedSeconds: TimeInterval
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.caption.bold())
            Text(formatted)
                .font(.callout.bold())
                .monospacedDigit()
        }
        .foregroundStyle(isPlaying ? Theme.accentSecondary : Theme.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Theme.surfaceElevated, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session time")
        .accessibilityValue(formatted)
    }

    private var formatted: String {
        let total = Int(elapsedSeconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
