//
//  RepertoirePickerView.swift
//  SwiftUI.Metronome
//
//  Lets the user pick the songs they're about to study from the main screen,
//  so the session is logged as a repertoire session when it ends.
//

import SwiftUI

struct RepertoirePickerView: View {
    @ObservedObject var engine: MetronomeEngine
    @Environment(\.dismiss) private var dismiss
    @State private var songs: [SongEntry]

    init(engine: MetronomeEngine) {
        self.engine = engine
        let existing = engine.repertoire.map { SongEntry(title: $0.title, band: $0.band, artworkURL: $0.artworkURL) }
        _songs = State(initialValue: existing.isEmpty ? [SongEntry(title: "", band: "")] : existing)
    }

    private var filledSongs: [RepertoireSong] {
        songs.map {
            RepertoireSong(
                title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines),
                band: $0.band.trimmingCharacters(in: .whitespacesAndNewlines),
                artworkURL: $0.artworkURL
            )
        }
        .filter { !$0.title.isEmpty || !$0.band.isEmpty }
    }

    private var canSave: Bool {
        filledSongs.allSatisfy { !$0.title.isEmpty && !$0.band.isEmpty }
    }

    private var bandSuggestions: [String] {
        var seen = Set<String>()
        let typed = filledSongs.map(\.band).filter { !$0.isEmpty }
        return (engine.historyStore.knownBands + typed)
            .filter { seen.insert($0.lowercased()).inserted }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach($songs) { $song in
                        SongRowView(song: $song, bandSuggestions: bandSuggestions)
                    }
                    .onDelete { songs.remove(atOffsets: $0) }
                    Button {
                        songs.append(SongEntry(title: "", band: ""))
                    } label: {
                        Label("Add Song", systemImage: "plus")
                    }
                } header: {
                    Text("Songs")
                } footer: {
                    Text("Press play and the practice is saved as a repertoire session with these songs.")
                }
                if !engine.repertoire.isEmpty {
                    Section {
                        Button("Clear Repertoire", role: .destructive) {
                            engine.repertoire = []
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Repertoire")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        engine.repertoire = filledSongs
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        #if os(macOS)
        .frame(minWidth: 460, idealWidth: 480, minHeight: 440, idealHeight: 520)
        #endif
    }
}
