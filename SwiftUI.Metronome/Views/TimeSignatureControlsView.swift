//
//  TimeSignatureControlsView.swift
//  SwiftUI.Metronome
//

import SwiftUI

struct TimeSignatureControlsView: View {
    @ObservedObject var engine: MetronomeEngine

    var body: some View {
        Theme.card {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label("Beats per Measure", systemImage: "ruler")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Stepper(value: $engine.beatsPerMeasure, in: 1...12) {
                        Text("\(engine.beatsPerMeasure)")
                            .font(.title3.bold())
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                            .frame(minWidth: 28)
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("Subdivision", systemImage: "waveform.path")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.textSecondary)

                    Picker("Subdivision", selection: $engine.subdivision) {
                        ForEach(Subdivision.allCases) { sub in
                            Text(sub.shortLabel).tag(sub)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }
}
