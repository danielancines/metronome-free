//
//  TrainingModeView.swift
//  SwiftUI.Metronome
//
//  "Speed Trainer" — gradually ramps the tempo up while practicing,
//  the classic technique guitarists use to build up speed on a lick.
//
//  The card itself always stays a single fixed-height row so toggling
//  the trainer never changes the main screen's layout — detail fields
//  live in a sheet, which always has room to show them fully.
//

import SwiftUI

struct TrainingModeView: View {
    @ObservedObject var engine: MetronomeEngine
    @State private var showingSettings = false

    var body: some View {
        Theme.card {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        engine.trainingModeEnabled.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Label("Speed Trainer", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        // Purely visual — the whole row above drives the actual toggle,
                        // since outside a List a bare Toggle only responds to taps on
                        // its small native switch knob, not its label.
                        Toggle("", isOn: $engine.trainingModeEnabled)
                            .labelsHidden()
                            .tint(Theme.accent)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Speed Trainer")
                .accessibilityValue(engine.trainingModeEnabled ? "On" : "Off")
                .accessibilityAddTraits(.isButton)

                if engine.trainingModeEnabled {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.accentSecondary)
                            .frame(width: 34, height: 34)
                            .background(Theme.accentSecondary.opacity(0.18), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Speed Trainer Settings")
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: engine.trainingModeEnabled)
        }
        .sheet(isPresented: $showingSettings) {
            TrainingSettingsSheet(engine: engine)
        }
    }
}

private struct TrainingSettingsSheet: View {
    @ObservedObject var engine: MetronomeEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Text("Speed Trainer")
                        .font(.title3.bold())
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
                }

                VStack(spacing: 16) {
                    trainingRow(label: "Start BPM", value: $engine.trainingStartBPM, range: 30...300)
                    trainingRow(label: "Target BPM", value: $engine.trainingTargetBPM, range: 30...300)
                    trainingRow(label: "Increase by", value: $engine.trainingIncrement, range: 1...20)

                    HStack {
                        Text("Every")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Stepper(value: $engine.trainingBarsPerIncrement, in: 1...16) {
                            Text("\(engine.trainingBarsPerIncrement) bar\(engine.trainingBarsPerIncrement > 1 ? "s" : "")")
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .fixedSize()
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    private func trainingRow(label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text("\(Int(value.wrappedValue))")
                .font(.subheadline.bold())
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .frame(minWidth: 32)
                .accessibilityIdentifier("Value.\(label)")
            Stepper("", value: value, in: range, step: 1)
                .labelsHidden()
                .accessibilityIdentifier("Stepper.\(label)")
        }
    }
}
