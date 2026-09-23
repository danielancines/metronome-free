//
//  TransportControlsView.swift
//  SwiftUI.Metronome
//

import SwiftUI

struct TransportControlsView: View {
    @ObservedObject var engine: MetronomeEngine

    var body: some View {
        HStack(spacing: 28) {
            circleButton(
                systemImage: "hand.tap.fill",
                caption: "TAP",
                isActive: false,
                action: engine.tapTempo
            )

            Button(action: engine.togglePlay) {
                Image(systemName: engine.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 32))
                    .frame(width: 92, height: 92)
                    .background(
                        engine.isPlaying ? Theme.danger : Theme.accent,
                        in: Circle()
                    )
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)

            circleButton(
                systemImage: engine.accentFirstBeat ? "metronome.fill" : "metronome",
                caption: "ACCENT",
                isActive: engine.accentFirstBeat,
                action: { engine.accentFirstBeat.toggle() }
            )
        }
    }

    private func circleButton(
        systemImage: String,
        caption: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                Text(caption)
                    .font(.caption2.bold())
                    .tracking(1)
            }
            .frame(width: 64, height: 64)
            .background(
                isActive ? Theme.accentSecondary.opacity(0.25) : Theme.surfaceElevated,
                in: Circle()
            )
            .foregroundStyle(isActive ? Theme.accentSecondary : Theme.textPrimary)
        }
        .buttonStyle(.plain)
    }
}
