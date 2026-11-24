//
//  TransportControlsView.swift
//  SwiftUI.Metronome
//

import SwiftUI

struct TransportControlsView: View {
    @ObservedObject var engine: MetronomeEngine

    var body: some View {
        VStack(spacing: 14) {
        HStack(spacing: 28) {
            circleButton(
                systemImage: "hand.tap.fill",
                caption: "TAP",
                isActive: false,
                action: engine.tapTempo
            )

            Button(action: engine.togglePlay) {
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 32))
                    .frame(width: 92, height: 92)
                    .background(
                        engine.isPlaying ? Theme.accentSecondary : Theme.accent,
                        in: Circle()
                    )
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(engine.isPlaying ? "Pause" : (engine.isPaused ? "Resume" : "Start"))

            circleButton(
                systemImage: engine.accentFirstBeat ? "metronome.fill" : "metronome",
                caption: "ACCENT",
                isActive: engine.accentFirstBeat,
                action: { engine.accentFirstBeat.toggle() }
            )
        }
        if engine.hasActiveSession {
            Button(action: engine.stop) {
                Label("END & SAVE", systemImage: "stop.fill")
                    .font(.caption.bold())
                    .tracking(1)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Theme.danger, in: Capsule())
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("End Session")
        }
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
