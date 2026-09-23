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
                        .listStyle(.insetGrouped)
                        .tint(Theme.accentSecondary)
                    }
                }
            }
            .navigationTitle("Practice History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
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
            }
            HStack(spacing: 14) {
                Label(durationText(session.duration), systemImage: "timer")
                Label("\(session.bpm) BPM", systemImage: "metronome")
                if session.usedSpeedTrainer {
                    Label("Speed Trainer", systemImage: "chart.line.uptrend.xyaxis")
                }
            }
            .font(.caption.bold())
            .foregroundStyle(Theme.accentSecondary)
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
