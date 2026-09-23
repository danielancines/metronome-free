//
//  MetronomeEngine.swift
//  SwiftUI.Metronome
//
//  Drives click playback using a lookahead scheduler: notes are scheduled
//  a fraction of a second ahead of time using host-time based AVAudioTime,
//  so audio stays sample-accurate even though the scheduling loop itself
//  runs on a plain timer. UI beat highlighting is synced with asyncAfter,
//  which is precise enough for a visual flash.
//

import AVFoundation
import Combine

@MainActor
final class MetronomeEngine: ObservableObject {

    static let bpmRange: ClosedRange<Double> = 30...300

    // MARK: Published state

    @Published var bpm: Double {
        didSet {
            let clamped = bpm.clamped(to: Self.bpmRange)
            if clamped != bpm { bpm = clamped; return }
            UserDefaults.standard.set(bpm, forKey: Keys.bpm)
        }
    }

    @Published var beatsPerMeasure: Int {
        didSet { UserDefaults.standard.set(beatsPerMeasure, forKey: Keys.beatsPerMeasure) }
    }

    @Published var subdivision: Subdivision {
        didSet { UserDefaults.standard.set(subdivision.rawValue, forKey: Keys.subdivision) }
    }

    @Published var accentFirstBeat: Bool {
        didSet { UserDefaults.standard.set(accentFirstBeat, forKey: Keys.accentFirstBeat) }
    }

    @Published var volume: Float {
        didSet {
            playerNode.volume = volume
            UserDefaults.standard.set(volume, forKey: Keys.volume)
        }
    }

    @Published private(set) var isPlaying = false
    @Published private(set) var currentBeat = 0
    @Published private(set) var currentSubTick = 0
    @Published private(set) var elapsedSeconds: TimeInterval = 0

    let historyStore = PracticeHistoryStore()

    // Speed trainer: gradually ramps the tempo up over a practice session.
    @Published var trainingModeEnabled = false
    @Published var trainingStartBPM: Double = 80
    @Published var trainingTargetBPM: Double = 140
    @Published var trainingIncrement: Double = 4
    @Published var trainingBarsPerIncrement: Int = 4

    // MARK: Audio graph

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var accentBuffer: AVAudioPCMBuffer!
    private var normalBuffer: AVAudioPCMBuffer!
    private var subdivisionBuffer: AVAudioPCMBuffer!

    // MARK: Scheduler

    private var schedulerTimer: DispatchSourceTimer?
    private var nextNoteTime: Double = 0
    private var nextNoteBeat = 0
    private var nextNoteSub = 0
    private var barCounterForTraining = 0

    private let scheduleAheadTime: Double = 0.15
    private let lookaheadInterval: Double = 0.02

    private var tapTimestamps: [Date] = []
    private var interruptionObserver: NSObjectProtocol?
    private var isAudioSessionConfigured = false

    private var sessionStartDate: Date?
    private var elapsedTimer: Timer?
    private static let minimumSessionDurationToLog: TimeInterval = 3

    private enum Keys {
        static let bpm = "metronome.bpm"
        static let beatsPerMeasure = "metronome.beatsPerMeasure"
        static let subdivision = "metronome.subdivision"
        static let accentFirstBeat = "metronome.accentFirstBeat"
        static let volume = "metronome.volume"
    }

    // MARK: Init

    init() {
        let defaults = UserDefaults.standard
        bpm = (defaults.object(forKey: Keys.bpm) as? Double ?? 100).clamped(to: Self.bpmRange)
        beatsPerMeasure = defaults.object(forKey: Keys.beatsPerMeasure) as? Int ?? 4
        if let rawSub = defaults.object(forKey: Keys.subdivision) as? Int,
           let sub = Subdivision(rawValue: rawSub) {
            subdivision = sub
        } else {
            subdivision = .quarter
        }
        accentFirstBeat = defaults.object(forKey: Keys.accentFirstBeat) as? Bool ?? true
        volume = defaults.object(forKey: Keys.volume) as? Float ?? 0.8

        setupAudioGraph()
        observeInterruptions()
    }

    deinit {
        schedulerTimer?.cancel()
        elapsedTimer?.invalidate()
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    // MARK: Setup

    private func setupAudioGraph() {
        engine.attach(playerNode)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2) else { return }
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        playerNode.volume = volume

        accentBuffer = ClickSoundGenerator.makeClickBuffer(format: format, frequency: 1600, duration: 0.05, amplitude: 0.9)
        normalBuffer = ClickSoundGenerator.makeClickBuffer(format: format, frequency: 1100, duration: 0.045, amplitude: 0.7)
        subdivisionBuffer = ClickSoundGenerator.makeClickBuffer(format: format, frequency: 850, duration: 0.03, amplitude: 0.45)

        engine.prepare()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("MetronomeEngine: failed to configure audio session — \(error)")
        }
    }

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let info = note.userInfo,
                  let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: rawType),
                  type == .began else { return }
            self.stop()
        }
    }

    // MARK: Transport

    func togglePlay() {
        isPlaying ? stop() : start()
    }

    func start() {
        guard !isPlaying else { return }

        if trainingModeEnabled {
            bpm = trainingStartBPM.clamped(to: Self.bpmRange)
        }

        if !isAudioSessionConfigured {
            configureAudioSession()
            isAudioSessionConfigured = true
        }

        do {
            if !engine.isRunning {
                try engine.start()
            }
        } catch {
            print("MetronomeEngine: failed to start audio engine — \(error)")
            return
        }

        playerNode.play()
        barCounterForTraining = 0
        nextNoteBeat = 0
        nextNoteSub = 0
        nextNoteTime = ProcessInfo.processInfo.systemUptime + 0.05
        isPlaying = true
        startScheduler()

        sessionStartDate = Date()
        elapsedSeconds = 0
        startElapsedTimer()
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        schedulerTimer?.cancel()
        schedulerTimer = nil
        playerNode.stop()
        currentBeat = 0
        currentSubTick = 0

        elapsedTimer?.invalidate()
        elapsedTimer = nil
        recordSessionIfNeeded()
        sessionStartDate = nil
        elapsedSeconds = 0
    }

    private func startElapsedTimer() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.sessionStartDate else { return }
            self.elapsedSeconds = Date().timeIntervalSince(start)
        }
        RunLoop.main.add(timer, forMode: .common)
        elapsedTimer = timer
    }

    private func recordSessionIfNeeded() {
        guard let start = sessionStartDate else { return }
        let duration = Date().timeIntervalSince(start)
        guard duration >= Self.minimumSessionDurationToLog else { return }

        let session = PracticeSession(
            date: start,
            duration: duration,
            bpm: Int(bpm.rounded()),
            beatsPerMeasure: beatsPerMeasure,
            subdivision: subdivision,
            usedSpeedTrainer: trainingModeEnabled
        )
        historyStore.add(session)
    }

    func adjustBPM(by delta: Double) {
        bpm = (bpm + delta).clamped(to: Self.bpmRange)
    }

    func tapTempo() {
        let now = Date()
        if let last = tapTimestamps.last, now.timeIntervalSince(last) > 2.0 {
            tapTimestamps.removeAll()
        }
        tapTimestamps.append(now)
        if tapTimestamps.count > 6 {
            tapTimestamps.removeFirst()
        }
        guard tapTimestamps.count >= 2 else { return }

        var intervals: [TimeInterval] = []
        for i in 1..<tapTimestamps.count {
            intervals.append(tapTimestamps[i].timeIntervalSince(tapTimestamps[i - 1]))
        }
        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        guard averageInterval > 0 else { return }

        bpm = (60.0 / averageInterval).clamped(to: Self.bpmRange)
    }

    // MARK: Scheduler loop

    private func startScheduler() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: lookaheadInterval)
        timer.setEventHandler { [weak self] in
            self?.schedulerTick()
        }
        schedulerTimer = timer
        timer.resume()
    }

    private func schedulerTick() {
        let now = ProcessInfo.processInfo.systemUptime
        while nextNoteTime < now + scheduleAheadTime {
            scheduleNote(beat: nextNoteBeat, sub: nextNoteSub, atTime: nextNoteTime)
            advanceNote()
        }
    }

    private func scheduleNote(beat: Int, sub: Int, atTime hostSeconds: Double) {
        let buffer: AVAudioPCMBuffer
        if sub == 0 {
            buffer = (beat == 0 && accentFirstBeat) ? accentBuffer : normalBuffer
        } else {
            buffer = subdivisionBuffer
        }

        let hostTime = AVAudioTime.hostTime(forSeconds: hostSeconds)
        let avTime = AVAudioTime(hostTime: hostTime)
        playerNode.scheduleBuffer(buffer, at: avTime, options: [], completionHandler: nil)

        let delay = max(0, hostSeconds - ProcessInfo.processInfo.systemUptime)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.isPlaying else { return }
            self.currentBeat = beat
            self.currentSubTick = sub
        }
    }

    private func advanceNote() {
        let ticksPerBeat = subdivision.ticksPerBeat
        let secondsPerBeat = 60.0 / bpm
        let secondsPerTick = secondsPerBeat / Double(ticksPerBeat)
        nextNoteTime += secondsPerTick

        nextNoteSub += 1
        if nextNoteSub >= ticksPerBeat {
            nextNoteSub = 0
            nextNoteBeat += 1
            if nextNoteBeat >= beatsPerMeasure {
                nextNoteBeat = 0
                barCounterForTraining += 1
                applyTrainingIncrementIfNeeded()
            }
        }
    }

    private func applyTrainingIncrementIfNeeded() {
        guard trainingModeEnabled, trainingBarsPerIncrement > 0 else { return }
        guard barCounterForTraining % trainingBarsPerIncrement == 0 else { return }
        guard bpm < trainingTargetBPM else { return }
        bpm = min(bpm + trainingIncrement, trainingTargetBPM)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
