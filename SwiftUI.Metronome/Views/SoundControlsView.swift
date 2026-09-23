//
//  SoundControlsView.swift
//  SwiftUI.Metronome
//

import SwiftUI

struct SoundControlsView: View {
    @ObservedObject var engine: MetronomeEngine

    var body: some View {
        Theme.card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Volume", systemImage: "speaker.wave.2.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 10) {
                    Image(systemName: "speaker.fill")
                        .foregroundStyle(Theme.textSecondary)
                    Slider(value: $engine.volume, in: 0...1)
                        .tint(Theme.accent)
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}
