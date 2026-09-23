//
//  TempoControlsView.swift
//  SwiftUI.Metronome
//

import SwiftUI

struct TempoControlsView: View {
    @ObservedObject var engine: MetronomeEngine

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                stepButton("−5") { engine.adjustBPM(by: -5) }
                stepButton("−1") { engine.adjustBPM(by: -1) }
                Spacer()
                stepButton("+1") { engine.adjustBPM(by: 1) }
                stepButton("+5") { engine.adjustBPM(by: 5) }
            }

            Slider(
                value: $engine.bpm,
                in: MetronomeEngine.bpmRange,
                step: 1
            )
            .tint(Theme.accent)
        }
    }

    private func stepButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.bold())
                .frame(width: 52, height: 38)
                .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(Theme.textPrimary)
        }
        .buttonStyle(.plain)
    }
}
