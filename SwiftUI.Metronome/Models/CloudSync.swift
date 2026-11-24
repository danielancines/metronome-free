//
//  CloudSync.swift
//  SwiftUI.Metronome
//
//  Syncs practice sessions through the user's private CloudKit database so
//  the same history shows up on every device signed in to the same Apple ID.
//  One CKRecord per session (recordName = session UUID); the session itself
//  is stored as a JSON payload so new fields never need a schema change.
//

import CloudKit
import Foundation
import os

@MainActor
final class CloudSync: CKSyncEngineDelegate {
    static let containerID = "iCloud.com.danielancines.SwiftUI-Metronome"
    private static let recordType = "PracticeSession"
    private static let zoneID = CKRecordZone.ID(zoneName: "Sessions", ownerName: CKCurrentUserDefaultName)

    private struct Metadata: Codable {
        var engineState: CKSyncEngine.State.Serialization?
        /// Archived CKRecord system fields (change tags) by record name.
        var systemFields: [String: Data] = [:]
    }

    private let log = Logger(subsystem: "com.danielancines.SwiftUI-Metronome", category: "CloudSync")
    private unowned let store: PracticeHistoryStore
    private var metadata: Metadata
    private var engine: CKSyncEngine!

    private static var metadataURL: URL {
        PracticeHistoryStore.defaultFileURL.deletingLastPathComponent().appendingPathComponent("cloudSyncState.json")
    }

    /// Returns nil when sync can't run (tests, no iCloud account), so the app
    /// keeps working purely locally.
    static func makeIfAvailable(store: PracticeHistoryStore) -> CloudSync? {
        let env = ProcessInfo.processInfo
        if env.environment["XCTestConfigurationFilePath"] != nil || env.arguments.contains("-disableCloudSync") {
            return nil
        }
        // No account check here: ubiquityIdentityToken is also nil when iCloud
        // Drive is off, which would silently disable CloudKit. CKSyncEngine
        // waits for an account by itself and reports it via accountChange.
        return CloudSync(store: store)
    }

    private init(store: PracticeHistoryStore) {
        self.store = store
        if let data = try? Data(contentsOf: Self.metadataURL),
           let decoded = try? JSONDecoder().decode(Metadata.self, from: data) {
            metadata = decoded
        } else {
            metadata = Metadata()
        }

        let container = CKContainer(identifier: Self.containerID)
        var configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: metadata.engineState,
            delegate: self
        )
        configuration.automaticallySync = true
        engine = CKSyncEngine(configuration)

        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
        // Sessions that never reached the cloud (existing history, offline edits).
        for session in store.sessions where metadata.systemFields[session.id.uuidString] == nil {
            queueSave(session.id)
        }
    }

    /// Pulls changes from other devices now (called when the app comes to the foreground).
    func refresh() async {
        do {
            try await engine.fetchChanges()
            try await engine.sendChanges()
        } catch {
            log.error("refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Queueing local changes

    func queueSave(_ id: UUID) {
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID(for: id))])
    }

    func queueDelete(_ id: UUID) {
        engine.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID(for: id))])
    }

    private func recordID(for id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: id.uuidString, zoneID: Self.zoneID)
    }

    // MARK: CKSyncEngineDelegate

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        log.info("event: \(String(describing: event).prefix(120), privacy: .public)")
        switch event {
        case .stateUpdate(let update):
            metadata.engineState = update.stateSerialization
            saveMetadata()

        case .accountChange(let change):
            switch change.changeType {
            case .signOut, .switchAccounts:
                // Another account's history must not leak into this one; start
                // over so everything local is re-uploaded to the new account.
                metadata = Metadata()
                saveMetadata()
            default:
                break
            }

        case .fetchedDatabaseChanges(let changes):
            // The zone was deleted from iCloud (e.g. "Delete data" in Settings):
            // push the local history back up.
            if changes.deletions.contains(where: { $0.zoneID == Self.zoneID }) {
                metadata.systemFields.removeAll()
                saveMetadata()
                engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
                store.sessions.forEach { queueSave($0.id) }
            }

        case .fetchedRecordZoneChanges(let changes):
            for modification in changes.modifications {
                receive(modification.record)
            }
            for deletion in changes.deletions {
                metadata.systemFields[deletion.recordID.recordName] = nil
                if let id = UUID(uuidString: deletion.recordID.recordName) {
                    store.applyRemoteDeletion(id)
                }
            }
            saveMetadata()

        case .sentRecordZoneChanges(let sent):
            for record in sent.savedRecords {
                metadata.systemFields[record.recordID.recordName] = Self.archiveSystemFields(of: record)
            }
            for id in sent.deletedRecordIDs {
                metadata.systemFields[id.recordName] = nil
            }
            for failure in sent.failedRecordSaves {
                handleSaveFailure(failure.record, error: failure.error)
            }
            saveMetadata()

        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        // Build the records up front, on the main actor.
        var built: [CKRecord.ID: CKRecord] = [:]
        for change in pending {
            guard case .saveRecord(let recordID) = change else { continue }
            if let id = UUID(uuidString: recordID.recordName), let session = store.session(withID: id) {
                built[recordID] = makeRecord(for: session)
            } else {
                // Deleted locally before it was sent.
                syncEngine.state.remove(pendingRecordZoneChanges: [change])
            }
        }
        let records = built
        let sendable = pending.filter {
            if case .saveRecord(let recordID) = $0 { return records[recordID] != nil }
            return true
        }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: sendable) { records[$0] }
    }

    // MARK: Records

    private func makeRecord(for session: PracticeSession) -> CKRecord {
        let name = session.id.uuidString
        let record: CKRecord
        if let data = metadata.systemFields[name], let restored = Self.restoreRecord(from: data) {
            record = restored
        } else {
            record = CKRecord(recordType: Self.recordType, recordID: recordID(for: session.id))
        }
        record["payload"] = try? JSONEncoder().encode(session)
        record["updatedAt"] = session.updatedAt
        return record
    }

    private func receive(_ record: CKRecord) {
        guard record.recordType == Self.recordType,
              let data = record["payload"] as? Data,
              let remote = try? JSONDecoder().decode(PracticeSession.self, from: data) else { return }
        metadata.systemFields[record.recordID.recordName] = Self.archiveSystemFields(of: record)
        if store.applyRemote(remote) {
            // Local copy is newer: send it back on top of the server's version.
            queueSave(remote.id)
        }
    }

    private func handleSaveFailure(_ record: CKRecord, error: CKError) {
        switch error.code {
        case .serverRecordChanged:
            // Someone else changed it first: adopt the server's change tag, then
            // keep whichever side is newer.
            if let server = error.serverRecord {
                receive(server)
                if let id = UUID(uuidString: server.recordID.recordName), store.session(withID: id) != nil {
                    queueSave(id)
                }
            }
        case .unknownItem:
            metadata.systemFields[record.recordID.recordName] = nil
            if let id = UUID(uuidString: record.recordID.recordName) { queueSave(id) }
        default:
            log.error("failed to save \(record.recordID.recordName, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Helpers

    private static func archiveSystemFields(of record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    private static func restoreRecord(from data: Data) -> CKRecord? {
        guard let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        coder.requiresSecureCoding = true
        return CKRecord(coder: coder)
    }

    private func saveMetadata() {
        do {
            try FileManager.default.createDirectory(
                at: Self.metadataURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(metadata).write(to: Self.metadataURL, options: .atomic)
        } catch {
            print("CloudSync: failed to save state — \(error)")
        }
    }
}
