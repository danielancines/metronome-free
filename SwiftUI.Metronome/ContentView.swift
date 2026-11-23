//
//  ContentView.swift
//  SwiftUI.Metronome
//
//  Created by Daniel Ancines on 23/09/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @StateObject private var engine = MetronomeEngine()
    @State private var showingHistory = false

    /// iPad, and any iPhone in landscape, get the wider two-column layout —
    /// both have more width than height to work with.
    private var useTwoColumn: Bool {
        horizontalSizeClass == .regular || verticalSizeClass == .compact
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            FitToHeight {
                VStack(spacing: 12) {
                    if useTwoColumn {
                        twoColumnLayout
                    } else {
                        singleColumnLayout
                    }
                    footer
                }
            }
            .padding(useTwoColumn ? 28 : 20)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingHistory) {
            HistoryView(historyStore: engine.historyStore)
        }
    }

    // MARK: iPhone portrait

    private var singleColumnLayout: some View {
        VStack(spacing: 16) {
            header

            BeatIndicatorView(
                beatsPerMeasure: engine.beatsPerMeasure,
                currentBeat: engine.currentBeat,
                isPlaying: engine.isPlaying,
                accentFirstBeat: engine.accentFirstBeat
            )

            TempoDisplayView(engine: engine)
            TempoControlsView(engine: engine)

            SessionTimerView(elapsedSeconds: engine.elapsedSeconds, isPlaying: engine.isPlaying)

            TransportControlsView(engine: engine)

            TimeSignatureControlsView(engine: engine)
            SoundControlsView(engine: engine)
            TrainingModeView(engine: engine)
        }
    }

    // MARK: iPad, and iPhone landscape

    private var twoColumnLayout: some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(spacing: 20) {
                header

                BeatIndicatorView(
                    beatsPerMeasure: engine.beatsPerMeasure,
                    currentBeat: engine.currentBeat,
                    isPlaying: engine.isPlaying,
                    accentFirstBeat: engine.accentFirstBeat
                )

                TempoDisplayView(engine: engine)
                TempoControlsView(engine: engine)

                SessionTimerView(elapsedSeconds: engine.elapsedSeconds, isPlaying: engine.isPlaying)

                TransportControlsView(engine: engine)
            }
            .frame(maxWidth: 440)

            VStack(spacing: 16) {
                TimeSignatureControlsView(engine: engine)
                SoundControlsView(engine: engine)
                TrainingModeView(engine: engine)
            }
            .frame(maxWidth: 440)
        }
    }

    private var footer: some View {
        VStack(spacing: 2) {
            Text(versionText)
                .accessibilityIdentifier("VersionLabel")
            Text("Copyright by Evil Dan")
        }
        .font(.caption2)
        .foregroundStyle(Theme.textSecondary.opacity(0.7))
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (\(build))"
    }

    private var header: some View {
        HStack {
            Color.clear.frame(width: 28, height: 28)
            Spacer()
            Text("EVIL METRONOME")
                .font(.caption.bold())
                .tracking(3)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Button {
                showingHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Practice History")
        }
    }
}

#Preview {
    ContentView()
}
