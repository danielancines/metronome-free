//
//  BeatIndicatorView.swift
//  SwiftUI.Metronome
//

import SwiftUI

struct BeatIndicatorView: View {
    let beatsPerMeasure: Int
    let currentBeat: Int
    let isPlaying: Bool
    let accentFirstBeat: Bool

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<beatsPerMeasure, id: \.self) { index in
                Circle()
                    .fill(color(for: index))
                    .frame(width: dotSize(for: index), height: dotSize(for: index))
                    .scaleEffect(isPlaying && currentBeat == index ? 1.3 : 1.0)
                    .animation(.easeOut(duration: 0.1), value: currentBeat)
            }
        }
        .frame(minHeight: 24)
    }

    private func dotSize(for index: Int) -> CGFloat {
        (index == 0 && accentFirstBeat) ? 16 : 12
    }

    private func color(for index: Int) -> Color {
        guard isPlaying, currentBeat == index else {
            return Theme.surfaceElevated
        }
        return (index == 0 && accentFirstBeat) ? Theme.accent : Theme.accentSecondary
    }
}

#Preview {
    BeatIndicatorView(beatsPerMeasure: 4, currentBeat: 0, isPlaying: true, accentFirstBeat: true)
        .padding()
        .background(Theme.background)
}
