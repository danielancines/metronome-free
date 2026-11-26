//
//  MetronomeEngine+NowPlaying.swift
//  SwiftUI.Metronome
//
//  Lock-screen / Control Center card for the running session: shows what is
//  being practiced and offers play/pause without unlocking the phone.
//

import MediaPlayer

#if os(iOS)
import UIKit

/// Album covers already downloaded for the lock-screen card, by URL.
@MainActor private var coverCache: [String: UIImage] = [:]

/// Fallback artwork: the metronome glyph on the app's dark background.
private let defaultArtwork: UIImage = {
    let size = CGSize(width: 512, height: 512)
    return UIGraphicsImageRenderer(size: size).image { ctx in
        UIColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1).setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
        let config = UIImage.SymbolConfiguration(pointSize: 260, weight: .semibold)
        if let glyph = UIImage(systemName: "metronome.fill", withConfiguration: config)?
            .withTintColor(UIColor(red: 0.3, green: 0.65, blue: 1, alpha: 1), renderingMode: .alwaysOriginal) {
            let origin = CGPoint(x: (size.width - glyph.size.width) / 2, y: (size.height - glyph.size.height) / 2)
            glyph.draw(at: origin)
        }
    }
}()

extension MetronomeEngine {
    static let nowPlayingStep: TimeInterval = 300

    /// Wires the lock-screen play/pause buttons (and headphone/remote controls).
    func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        // Idempotent: called on every start().
        [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand]
            .forEach { $0.removeTarget(nil) }

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.start() }
            return .success
        }
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlay() }
            return .success
        }
        // A metronome has no tracks or scrubbing.
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
        center.changePlaybackPositionCommand.isEnabled = false
        center.skipForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = false
    }

    /// Refreshes (or clears) the lock-screen card. Call whenever the session
    /// state, tempo, or chosen songs change.
    func updateNowPlaying() {
        let center = MPNowPlayingInfoCenter.default()
        guard hasActiveSession else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            return
        }

        var info: [String: Any] = [:]
        if let song = repertoire.first {
            info[MPMediaItemPropertyTitle] = song.title
            let extra = repertoire.count > 1 ? " +\(repertoire.count - 1)" : ""
            info[MPMediaItemPropertyArtist] = (song.band.isEmpty ? "Repertoire" : song.band) + extra
            info[MPMediaItemPropertyAlbumTitle] = "Evil Metronome · \(Int(bpm.rounded())) BPM"
        } else {
            info[MPMediaItemPropertyTitle] = "\(Int(bpm.rounded())) BPM"
            info[MPMediaItemPropertyArtist] = "Evil Metronome"
            info[MPMediaItemPropertyAlbumTitle] = "Practice · \(beatsPerMeasure) beats"
        }
        let artwork = nowPlayingArtwork()
        info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        // A session has no fixed length, so the bar fills towards the next
        // 5-minute mark and is extended each time that mark is reached.
        let step = Self.nowPlayingStep
        nowPlayingDuration = (floor(elapsedSeconds / step) + 1) * step
        info[MPMediaItemPropertyPlaybackDuration] = nowPlayingDuration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedSeconds
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        center.nowPlayingInfo = info
        center.playbackState = isPlaying ? .playing : .paused
    }

    /// The first song's cover when there is one (downloaded on demand), else the app glyph.
    private func nowPlayingArtwork() -> UIImage {
        guard let urlString = repertoire.first?.artworkURL, let url = URL(string: urlString) else {
            return defaultArtwork
        }
        if let cached = coverCache[urlString] { return cached }
        Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { return }
            coverCache[urlString] = image
            self?.updateNowPlaying()
        }
        return defaultArtwork
    }
}
#else
extension MetronomeEngine {
    func setupRemoteCommands() {}
    func updateNowPlaying() {}
}
#endif
