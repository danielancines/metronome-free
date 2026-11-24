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
    @State private var showingRepertoire = false

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
        .sheet(isPresented: $showingRepertoire) {
            RepertoirePickerView(engine: engine)
        }
    }

    // MARK: iPhone portrait

    private var singleColumnLayout: some View {
        VStack(spacing: 16) {
            header
            nowPlayingSongs

            BeatIndicatorView(
                beatsPerMeasure: engine.beatsPerMeasure,
                currentBeat: engine.currentBeat,
                isPlaying: engine.isPlaying,
                accentFirstBeat: engine.accentFirstBeat
            )

            TempoDisplayView(engine: engine)
            TempoControlsView(engine: engine)

            SessionTimerView(elapsedSeconds: engine.elapsedSeconds, isPlaying: engine.isPlaying, isPaused: engine.isPaused)

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
                nowPlayingSongs

                BeatIndicatorView(
                    beatsPerMeasure: engine.beatsPerMeasure,
                    currentBeat: engine.currentBeat,
                    isPlaying: engine.isPlaying,
                    accentFirstBeat: engine.accentFirstBeat
                )

                TempoDisplayView(engine: engine)
                TempoControlsView(engine: engine)

                SessionTimerView(elapsedSeconds: engine.elapsedSeconds, isPlaying: engine.isPlaying, isPaused: engine.isPaused)

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

    /// The songs picked for this session, so it's clear what is being studied.
    @ViewBuilder
    private var nowPlayingSongs: some View {
        if !engine.repertoire.isEmpty {
            Button {
                showingRepertoire = true
            } label: {
                VStack(spacing: 4) {
                    ForEach(Array(engine.repertoire.prefix(3).enumerated()), id: \.offset) { _, song in
                        HStack(spacing: 8) {
                            ArtworkView(urlString: song.artworkURL, size: 28)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(song.title)
                                    .font(.caption.bold())
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                Text(song.band)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    if engine.repertoire.count > 3 {
                        Text("+\(engine.repertoire.count - 3) more")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(6)
                .frame(maxWidth: 360, alignment: .leading)
                .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Repertoire songs")
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
            Button {
                showingRepertoire = true
            } label: {
                Image(systemName: "music.note.list")
                    .font(.subheadline)
                    .foregroundStyle(engine.repertoire.isEmpty ? Theme.textSecondary : Theme.accent)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Practice Repertoire")
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
