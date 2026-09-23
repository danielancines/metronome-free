//
//  TempoDisplayView.swift
//  SwiftUI.Metronome
//

import SwiftUI

struct TempoDisplayView: View {
    @ObservedObject var engine: MetronomeEngine

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(engine.bpm.rounded()))")
                .font(.system(size: 92, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
                .animation(.snappy, value: Int(engine.bpm.rounded()))
            Text("BPM")
                .font(.subheadline.bold())
                .tracking(4)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
