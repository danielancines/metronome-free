//
//  ClickSoundGenerator.swift
//  SwiftUI.Metronome
//
//  Synthesizes short percussive click tones so the metronome doesn't
//  depend on bundled audio assets.
//

import AVFoundation

enum ClickSoundGenerator {

    static func makeClickBuffer(
        format: AVAudioFormat,
        frequency: Double,
        duration: Double,
        amplitude: Float
    ) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            fatalError("Unable to allocate click buffer")
        }
        buffer.frameLength = frameCount

        let channelCount = Int(format.channelCount)
        let thetaIncrement = 2.0 * Double.pi * frequency / sampleRate
        var theta = 0.0
        let attackFraction = 0.04

        for frame in 0..<Int(frameCount) {
            let progress = Double(frame) / Double(frameCount)
            let envelope: Float
            if progress < attackFraction {
                envelope = Float(progress / attackFraction)
            } else {
                let decayProgress = (progress - attackFraction) / (1.0 - attackFraction)
                envelope = Float(pow(1.0 - decayProgress, 2.0))
            }

            let sample = Float(sin(theta)) * amplitude * envelope
            for channel in 0..<channelCount {
                buffer.floatChannelData?[channel][frame] = sample
            }

            theta += thetaIncrement
            if theta > 2.0 * .pi {
                theta -= 2.0 * .pi
            }
        }

        return buffer
    }
}
