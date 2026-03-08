// AudioFeedbackService.swift
// Plays a single generic alert tone through the headphones when any sound
// category is detected. Content-free attention cue for Experiment 2 (Visual + Audio).

import AVFoundation

final class AudioFeedbackService {

    static let shared = AudioFeedbackService()

    private var isEnabled: Bool = false
    private var tonePlayer: AVTonePLayer?

    private init() {}

    // MARK: - Public API

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        print("🔊 AudioFeedback.setEnabled(\(enabled))")
        if enabled && tonePlayer == nil {
            tonePlayer = AVTonePLayer()
        }
    }

    private var lastBeepTime: CFTimeInterval = 0
    private let minimumInterval: CFTimeInterval = 2.0  // One beep per detection, not per pulse

    func playAlertBeep() {
        guard isEnabled else { return }

        let now = CACurrentMediaTime()
        guard (now - lastBeepTime) >= minimumInterval else { return }
        lastBeepTime = now

        tonePlayer?.playTone()
    }

    func play(for category: SoundCategory) {
        playAlertBeep()
    }
}

// MARK: - Tone Player using its own AVAudioEngine

final class AVTonePLayer {

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var beepBuffer: AVAudioPCMBuffer?
    private var format: AVAudioFormat?

    init() {
        setupEngine()
    }

    private func setupEngine() {
        let sampleRate: Double = 44100
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        self.format = fmt

        // Generate beep buffer
        let duration: Double = 0.5
        let totalFrames = Int(sampleRate * duration)
        let halfPoint = totalFrames / 2

        guard let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(totalFrames)) else { return }
        buffer.frameLength = AVAudioFrameCount(totalFrames)

        let data = buffer.floatChannelData![0]
        for i in 0..<totalFrames {
            let t = Double(i) / sampleRate
            let freq: Double = i < halfPoint ? 880.0 : 1100.0

            let fadeFrames = Int(sampleRate * 0.005)
            let envelope: Float
            if i < fadeFrames {
                envelope = Float(i) / Float(fadeFrames)
            } else if i > totalFrames - fadeFrames {
                envelope = Float(totalFrames - i) / Float(fadeFrames)
            } else {
                envelope = 1.0
            }
            data[i] = sinf(Float(2.0 * .pi * freq * t)) * 0.08 * envelope
        }
        self.beepBuffer = buffer

        // Attach player node to engine
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: fmt)
        engine.mainMixerNode.outputVolume = 1.0
        playerNode.volume = 0.15

        do {
            try engine.start()
            print("🔊 TonePlayer engine started")
        } catch {
            print("⚠️ TonePlayer engine failed: \(error)")
        }
    }

    func playTone() {
        guard let buffer = beepBuffer else {
            print("⚠️ TonePlayer: no buffer")
            return
        }

        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("⚠️ TonePlayer restart failed: \(error)")
                return
            }
        }

        playerNode.stop()
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        playerNode.play()
        print("🔊 TonePlayer: tone scheduled and playing")
    }
}
