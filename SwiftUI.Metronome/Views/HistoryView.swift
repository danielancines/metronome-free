//
//  HistoryView.swift
//  SwiftUI.Metronome
//
//  A log of past practice sessions, grouped by day — today expanded,
//  earlier days collapsed so long history stays compact.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var historyStore: PracticeHistoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var expandedDays: Set<Date> = []
    @State private var showingClearAllConfirmation = false
    @State private var sessionPendingDeletion: PracticeSession?
    @State private var sessionBeingEdited: PracticeSession?
    @State private var sessionBeingAdded: PracticeSession?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if historyStore.sessions.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        overallSummary
                            .padding(.horizontal)
                            .padding(.vertical, 10)

                        List {
                            ForEach(groupedSessions, id: \.day) { group in
                                DisclosureGroup(isExpanded: isExpandedBinding(for: group.day)) {
                                    ForEach(group.sessions) { session in
                                        sessionRow(session)
                                            .contentShape(Rectangle())
                                            .onTapGesture { sessionBeingEdited = session }
                                            .contextMenu {
                                                Button {
                                                    sessionBeingEdited = session
                                                } label: {
                                                    Label("Edit", systemImage: "pencil")
                                                }
                                                Button(role: .destructive) {
                                                    sessionPendingDeletion = session
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                                Button {
                                                    sessionBeingEdited = session
                                                } label: {
                                                    Label("Edit", systemImage: "pencil")
                                                }
                                                .tint(Theme.accent)
                                            }
                                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                Button(role: .destructive) {
                                                    sessionPendingDeletion = session
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                    }
                                } label: {
                                    dayHeader(group)
                                }
                                .listRowBackground(Theme.surface)
                            }
                        }
                        .scrollContentBackground(.hidden)
                        #if os(iOS)
                        .listStyle(.insetGrouped)
                        #endif
                        .tint(Theme.accentSecondary)
                    }
                }
            }
            .navigationTitle("Practice History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            sessionBeingAdded = PracticeSession.draft(kind: .practice)
                        } label: {
                            Label("Practice Session", systemImage: "metronome")
                        }
                        Button {
                            sessionBeingAdded = PracticeSession.draft(kind: .repertoire)
                        } label: {
                            Label("Repertoire Session", systemImage: "music.note.list")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel("Add Session")
                }
                if !historyStore.sessions.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) {
                            showingClearAllConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(Theme.danger)
                    }
                }
            }
            .onAppear {
                expandedDays.insert(Calendar.current.startOfDay(for: Date()))
            }
            .sheet(item: $sessionBeingEdited) { session in
                EditSessionView(session: session, isNew: false, knownBands: historyStore.knownBands) { historyStore.update($0) }
            }
            .sheet(item: $sessionBeingAdded) { draft in
                EditSessionView(session: draft, isNew: true, knownBands: historyStore.knownBands) { historyStore.add($0) }
            }
            .alert(
                "Clear All Practice History?",
                isPresented: $showingClearAllConfirmation
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    historyStore.clearAll()
                }
            } message: {
                Text("This permanently deletes all \(historyStore.sessions.count) recorded session\(historyStore.sessions.count == 1 ? "" : "s"). This can't be undone.")
            }
            .alert(
                "Delete This Session?",
                isPresented: Binding(
                    get: { sessionPendingDeletion != nil },
                    set: { if !$0 { sessionPendingDeletion = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) {
                    sessionPendingDeletion = nil
                }
                Button("Delete", role: .destructive) {
                    if let session = sessionPendingDeletion {
                        historyStore.delete(session)
                    }
                    sessionPendingDeletion = nil
                }
            } message: {
                Text("This can't be undone.")
            }
        }
        .preferredColorScheme(.dark)
        #if os(macOS)
        // Sheets on macOS size to their content; a List has no intrinsic
        // size, so without this the history collapses to nothing.
        .frame(minWidth: 480, idealWidth: 520, minHeight: 520, idealHeight: 600)
        #endif
    }

    // MARK: Grouping

    private var groupedSessions: [(day: Date, sessions: [PracticeSession])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: historyStore.sessions) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { day in
            (day: day, sessions: groups[day]!.sorted { $0.date > $1.date })
        }
    }

    private func isExpandedBinding(for day: Date) -> Binding<Bool> {
        Binding(
            get: { expandedDays.contains(day) },
            set: { isExpanded in
                if isExpanded {
                    expandedDays.insert(day)
                } else {
                    expandedDays.remove(day)
                }
            }
        )
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: day)
    }

    // MARK: Subviews

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textSecondary)
            Text("No practice sessions yet")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("Start the metronome and practice for a bit — sessions show up here.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 40)
        }
    }

    private var overallSummary: some View {
        HStack {
            Text("\(historyStore.sessions.count) session\(historyStore.sessions.count == 1 ? "" : "s")")
                .accessibilityIdentifier("HistorySummaryCount")
            Spacer()
            Text("Total: \(durationText(historyStore.totalPracticeTime))")
        }
        .font(.caption.bold())
        .foregroundStyle(Theme.textSecondary)
    }

    private func dayHeader(_ group: (day: Date, sessions: [PracticeSession])) -> some View {
        HStack {
            Text(dayTitle(group.day))
                .font(.subheadline.bold())
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text("\(group.sessions.count) · \(durationText(group.sessions.reduce(0) { $0 + $1.duration }))")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func sessionRow(_ session: PracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.date, style: .date)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(session.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                #if os(macOS)
                Button { sessionBeingEdited = session } label: { Image(systemName: "pencil") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Edit Session")
                Button { sessionPendingDeletion = session } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.danger)
                    .accessibilityLabel("Delete Session")
                #endif
            }
            HStack(spacing: 14) {
                if session.kind == .repertoire {
                    Label("Repertoire", systemImage: "music.note.list")
                    if session.duration > 0 {
                        Label(durationText(session.duration), systemImage: "timer")
                    }
                } else {
                    Label(durationText(session.duration), systemImage: "timer")
                    Label("\(session.bpm) BPM", systemImage: "metronome")
                    if session.usedSpeedTrainer {
                        Label("Speed Trainer", systemImage: "chart.line.uptrend.xyaxis")
                    }
                }
            }
            .font(.caption.bold())
            .foregroundStyle(Theme.accentSecondary)
            if !session.notes.isEmpty {
                Text(session.notes)
                    .font(.caption)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if session.kind == .repertoire, !session.songs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(session.songs.enumerated()), id: \.offset) { _, song in
                        HStack(spacing: 8) {
                            ArtworkView(urlString: song.artworkURL, size: 32)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(song.title)
                                    .font(.caption.bold())
                                    .foregroundStyle(Theme.textPrimary)
                                if !song.band.isEmpty {
                                    Text(song.band)
                                        .font(.caption2)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("SessionRow")
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let total = Int(duration.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Edit sheet

private extension PracticeSession {
    /// A blank session used to seed the "add" sheet.
    static func draft(kind: SessionKind) -> PracticeSession {
        PracticeSession(
            date: Date(),
            duration: kind == .practice ? 300 : 0,
            bpm: kind == .practice ? 100 : 0,
            beatsPerMeasure: 4,
            subdivision: .quarter,
            usedSpeedTrainer: false,
            kind: kind
        )
    }
}

struct SongEntry: Identifiable {
    let id = UUID()
    var title: String
    var band: String
    var artworkURL: String?
}

/// Album cover thumbnail, with a neutral placeholder when there is none.
struct ArtworkView: View {
    let urlString: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.15))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            Theme.surfaceElevated
            Image(systemName: "music.note")
                .font(.system(size: size * 0.4))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

/// One song in the repertoire form: title + band, with live suggestions from
/// the iTunes Search API while the title field is being edited.
struct SongRowView: View {
    @Binding var song: SongEntry
    let bandSuggestions: [String]

    @FocusState private var titleFocused: Bool
    @State private var results: [MusicSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var justSelected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ArtworkView(urlString: song.artworkURL, size: 44)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        TextField("Song", text: $song.title)
                            .focused($titleFocused)
                            .onChange(of: song.title) { _, newValue in
                                if justSelected {
                                    justSelected = false
                                    return
                                }
                                // The cover belonged to the previously picked
                                // song; typing a different title invalidates it.
                                song.artworkURL = nil
                                search(for: newValue)
                            }
                        if isSearching {
                            ProgressView().controlSize(.small)
                        }
                    }
                    HStack {
                        TextField("Band", text: $song.band)
                        if !bandSuggestions.isEmpty {
                            Menu {
                                ForEach(bandSuggestions, id: \.self) { band in
                                    Button(band) { song.band = band }
                                }
                            } label: {
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                            }
                            .accessibilityLabel("Choose Band")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                }
            }

            if titleFocused, !results.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(results) { result in
                        Button {
                            select(result)
                        } label: {
                            HStack(spacing: 10) {
                                ArtworkView(urlString: result.artworkURL, size: 36)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(result.title)
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(result.band)
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if result != results.last { Divider() }
                    }
                }
                .padding(.top, 2)
            }
        }
        .onDisappear { searchTask?.cancel() }
    }

    private func search(for text: String) {
        searchTask?.cancel()
        let term = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Only search while the user is typing in the field, not when a
        // suggestion fills it in, and wait for a couple of characters.
        guard titleFocused, term.count >= 2 else {
            results = []
            isSearching = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400)) // debounce
            guard !Task.isCancelled else { return }
            isSearching = true
            let found = try? await MusicSearchService.search(term)
            guard !Task.isCancelled else { return }
            // A failed search (offline, rate-limited) just hides suggestions;
            // the fields stay editable by hand.
            results = found ?? []
            isSearching = false
        }
    }

    private func select(_ result: MusicSearchResult) {
        searchTask?.cancel()
        titleFocused = false
        results = []
        isSearching = false
        // Setting an identical title doesn't trigger onChange, so only arm the
        // flag when the title will actually change.
        justSelected = song.title != result.title
        song.title = result.title
        song.band = result.band
        song.artworkURL = result.artworkURL
    }
}

private struct EditSessionView: View {
    let session: PracticeSession
    let isNew: Bool
    let knownBands: [String]
    let onSave: (PracticeSession) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int
    @State private var seconds: Int
    @State private var bpm: Int
    @State private var date: Date
    @State private var songs: [SongEntry]
    @State private var notes: String

    init(session: PracticeSession, isNew: Bool, knownBands: [String], onSave: @escaping (PracticeSession) -> Void) {
        self.session = session
        self.isNew = isNew
        self.knownBands = knownBands
        self.onSave = onSave
        let total = Int(session.duration.rounded())
        _minutes = State(initialValue: total / 60)
        _seconds = State(initialValue: total % 60)
        _bpm = State(initialValue: session.bpm == 0 ? 100 : session.bpm)
        _date = State(initialValue: session.date)
        _notes = State(initialValue: session.notes)
        let existing = session.songs.map { SongEntry(title: $0.title, band: $0.band, artworkURL: $0.artworkURL) }
        _songs = State(initialValue: existing.isEmpty && session.kind == .repertoire ? [SongEntry(title: "", band: "")] : existing)
    }

    private var isRepertoire: Bool { session.kind == .repertoire }
    private var bpmRange: ClosedRange<Int> { 30...300 }
    private var totalSeconds: Int { minutes * 60 + seconds }
    /// Entries the user actually filled in (fully blank rows are ignored).
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
        if isRepertoire {
            let filled = filledSongs
            return !filled.isEmpty && filled.allSatisfy { !$0.title.isEmpty && !$0.band.isEmpty }
        }
        return totalSeconds > 0
    }
    /// Bands from past sessions plus the ones already typed in this sheet.
    private var bandSuggestions: [String] {
        var seen = Set<String>()
        let typed = filledSongs.map(\.band).filter { !$0.isEmpty }
        return (knownBands + typed)
            .filter { seen.insert($0.lowercased()).inserted }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Notes") {
                    TextField("Notes…", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                        .accessibilityIdentifier("SessionNotes")
                }
                Section("Date") {
                    DatePicker("Started", selection: $date, in: ...Date())
                }
                if isRepertoire {
                    Section("Songs") {
                        ForEach($songs) { $song in
                            SongRowView(song: $song, bandSuggestions: bandSuggestions)
                        }
                        .onDelete { songs.remove(atOffsets: $0) }
                        Button {
                            songs.append(SongEntry(title: "", band: ""))
                        } label: {
                            Label("Add Song", systemImage: "plus")
                        }
                    }
                }
                Section(isRepertoire ? "Duration (optional)" : "Duration") {
                    Stepper("Minutes: \(minutes)", value: $minutes, in: 0...999)
                    Stepper("Seconds: \(seconds)", value: $seconds, in: 0...59)
                }
                if !isRepertoire {
                    Section("Tempo") {
                        Stepper("\(bpm) BPM", value: $bpm, in: bpmRange)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = session
                        updated.duration = TimeInterval(totalSeconds)
                        updated.date = date
                        updated.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        if isRepertoire {
                            updated.songs = filledSongs
                        } else {
                            updated.bpm = bpm
                        }
                        onSave(updated)
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

    private var title: String {
        switch (isNew, isRepertoire) {
        case (true, true): return "New Repertoire"
        case (true, false): return "New Session"
        case (false, true): return "Edit Repertoire"
        case (false, false): return "Edit Session"
        }
    }
}
