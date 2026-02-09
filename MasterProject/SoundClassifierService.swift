// SoundClassifierService.swift
// UPDATE: Replace your entire existing SoundClassifierService.swift with this

import AVFoundation
import SoundAnalysis
import Combine
import UIKit

@MainActor
final class SoundClassifierService: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isListening: Bool = false
    @Published var latestRaw: SoundPrediction?
    @Published var lastUpdate: Date?

    /// Current awareness display (what the participant sees)
    @Published var currentDisplay: AwarenessDisplayState?

    /// Pulse IDs per category (drives animations)
    @Published var pulseIDs: [SoundCategory: Int] = {
        var dict: [SoundCategory: Int] = [:]
        for cat in SoundCategory.allCases { dict[cat] = 0 }
        return dict
    }()

    /// Currently detected category
    @Published var activeCategory: SoundCategory?

    @Published var hapticsEnabled: Bool = true {
        didSet { HapticService.shared.setEnabled(hapticsEnabled) }
    }
    @Published var recentTrustEvents: [TrustEvent] = []
    @Published var feedbackLog: [UserFeedback] = []

    // MARK: - Experiment Integration

    weak var sessionManager: ExperimentSessionManager?

    /// For reaction time measurement
    var currentNotificationOnsetTime: Date?

    // MARK: - Audio Pipeline

    private nonisolated(unsafe) var audioEngine = AVAudioEngine()
    private nonisolated(unsafe) var analyzer: SNAudioStreamAnalyzer?
    private nonisolated(unsafe) var request: SNClassifySoundRequest?
    private nonisolated(unsafe) var observer: ResultsObserver?

    // MARK: - Awareness Card Tuning

    private let displayThreshold: Double = 0.65
    private let minConsecutive: Int = 2
    private let holdDuration: TimeInterval = 2.0 // Extended from 1.0 to keep card visible longer

    /// Some sounds (cough, scream) are transient and may only appear for 1 frame.
    /// These categories can display with just 1 frame at higher confidence.
    private let transientCategories: Set<SoundCategory> = [.coughing, .glassBreaking, .knocking]
    private let transientSingleFrameThreshold: Double = 0.40 // Show after 1 frame if confidence ≥ this

    private var candidateCategory: SoundCategory?
    private var candidateCount: Int = 0
    private var clearStableToken: UUID?

    // MARK: - Pulse Tuning Per Category

    private struct PulseConfig {
        let peakThreshold: Double
        let minPulseInterval: Double
        let graceSeconds: Double
        let confidenceThreshold: Double
        let onsetMinInterval: Double
    }

    private let pulseConfigs: [SoundCategory: PulseConfig] = [
        .knocking:      PulseConfig(peakThreshold: 0.20, minPulseInterval: 0.10, graceSeconds: 1.00, confidenceThreshold: 0.25, onsetMinInterval: 0.35),
        .dogBarking:    PulseConfig(peakThreshold: 0.20, minPulseInterval: 0.14, graceSeconds: 1.20, confidenceThreshold: 0.30, onsetMinInterval: 0.40),
        .babyCrying:    PulseConfig(peakThreshold: 0.18, minPulseInterval: 0.14, graceSeconds: 1.40, confidenceThreshold: 0.30, onsetMinInterval: 0.40),
        .coughing:      PulseConfig(peakThreshold: 0.15, minPulseInterval: 1.50, graceSeconds: 1.50, confidenceThreshold: 0.20, onsetMinInterval: 1.80),
        .glassBreaking: PulseConfig(peakThreshold: 0.15, minPulseInterval: 3.00, graceSeconds: 0.0, confidenceThreshold: 0.25, onsetMinInterval: 3.00),
        .alarm:         PulseConfig(peakThreshold: 0.18, minPulseInterval: 0.12, graceSeconds: 1.60, confidenceThreshold: 0.25, onsetMinInterval: 0.45),
    ]

    private var eligibleUntil: [SoundCategory: CFTimeInterval] = [:]
    private var lastPulseTime: [SoundCategory: CFTimeInterval] = [:]
    private var lastOnsetTime: [SoundCategory: CFTimeInterval] = [:]

    private nonisolated(unsafe) var currentAmplitude: Double = 0

    // MARK: - Public API

    func start() {
        guard !isListening else { return }
        do {
            resetState()
            try configureAudioSession()
            try startEngineAndAnalyzer()
            isListening = true
        } catch {
            print("❌ Start failed:", error)
            stop()
        }
    }

    func stop() {
        guard isListening else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        analyzer = nil
        request = nil
        observer = nil
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ Could not deactivate audio session:", error)
        }
        isListening = false
        resetState()
    }

    /// Called when participant taps confirm button
    func handleConfirmTap() {
        guard let manager = sessionManager,
              let display = currentDisplay,
              let onset = currentNotificationOnsetTime else { return }

        manager.recordTapResponse(
            displayedCategory: display.category,
            displayedIntensity: display.intensityLevel,
            notificationOnsetTime: onset
        )
    }

    func addFeedback(verdict: UserFeedback.Verdict) {
        guard let shown = latestRaw else { return }
        let item = UserFeedback(date: Date(), label: shown.label, confidence: shown.confidence, verdict: verdict)
        feedbackLog.insert(item, at: 0)
        if feedbackLog.count > 50 { feedbackLog.removeLast() }
    }

    // MARK: - Internals

    private func resetState() {
        latestRaw = nil
        currentDisplay = nil
        lastUpdate = nil
        activeCategory = nil
        currentNotificationOnsetTime = nil
        candidateCategory = nil
        candidateCount = 0
        clearStableToken = nil
        for cat in SoundCategory.allCases {
            pulseIDs[cat] = 0
            eligibleUntil[cat] = 0
            lastPulseTime[cat] = 0
            lastOnsetTime[cat] = 0
        }
    }

    private nonisolated func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default,
                                options: [.mixWithOthers, .allowBluetoothHFP])
        try session.setActive(true)
    }

    private func startEngineAndAnalyzer() throws {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        analyzer = SNAudioStreamAnalyzer(format: format)
        request = try SNClassifySoundRequest(classifierIdentifier: .version1)

        observer = ResultsObserver { [weak self] label, confidence in
            guard let self else { return }
            let pred = SoundPrediction(label: label, confidence: confidence)
            Task { @MainActor in
                self.lastUpdate = pred.date
                self.latestRaw = pred
                self.updateStableDisplay(with: pred)
                self.updateEligibilityWindows(with: pred)
            }
        }

        if let request, let observer {
            try analyzer?.add(request, withObserver: observer)
        }

        inputNode.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, time in
            guard let self else { return }
            self.analyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
            let amp = self.computeRMSAmplitude(buffer: buffer)
            self.currentAmplitude = amp
            Task { @MainActor in
                self.handleAmplitude(amp)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    // MARK: - Awareness Stability

    private func updateStableDisplay(with pred: SoundPrediction) {
        guard let category = pred.category else {
            // Unknown label — don't clear immediately, just skip
            if pred.confidence < 0.30 { scheduleStableClear() }
            return
        }

        // Below minimum threshold — schedule clear
        guard pred.confidence >= (transientCategories.contains(category) ? transientSingleFrameThreshold : displayThreshold) else {
            scheduleStableClear()
            return
        }

        if category == candidateCategory {
            candidateCount += 1
        } else {
            candidateCategory = category
            candidateCount = 1
        }

        // Fast path: transient sounds can show after 1 frame at sufficient confidence
        let canDisplay: Bool
        if transientCategories.contains(category) && pred.confidence >= transientSingleFrameThreshold {
            canDisplay = true // Single frame is enough for transient sounds
        } else {
            canDisplay = candidateCount >= minConsecutive && pred.confidence >= displayThreshold
        }

        if canDisplay {
            let intensity: IntensityLevel

            // For single-event animations, lock intensity once set — don't let it flip mid-animation
            let singleEventCategories: Set<SoundCategory> = [.glassBreaking, .coughing]
            if singleEventCategories.contains(category),
               let existing = currentDisplay, existing.category == category {
                intensity = existing.intensityLevel
            } else if let manager = sessionManager {
                intensity = manager.resolveIntensity(
                    for: category,
                    atSessionTime: manager.secondsSinceBlockStart,
                    amplitude: currentAmplitude
                )
            } else {
                intensity = currentAmplitude > 0.30 ? .urgent : .routine
            }

            let newDisplay = AwarenessDisplayState(
                category: category, confidence: pred.confidence,
                intensityLevel: intensity, timestamp: Date()
            )

            if currentDisplay?.category != category || currentDisplay == nil {
                currentNotificationOnsetTime = Date()
            }

            currentDisplay = newDisplay
            activeCategory = category
            cancelStableClear()

            sessionManager?.logDetection(
                predictedLabel: pred.label,
                mappedCategory: category,
                confidence: pred.confidence,
                displayedIntensity: intensity,
                pulseCount: pulseIDs[category] ?? 0
            )
        }
    }

    private func scheduleStableClear() {
        guard currentDisplay != nil else { return }
        let token = UUID()
        clearStableToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) { [weak self] in
            guard let self, self.clearStableToken == token else { return }
            if let display = self.currentDisplay {
                self.sessionManager?.recordNoResponse(
                    displayedCategory: display.category,
                    displayedIntensity: display.intensityLevel
                )
            }
            self.currentDisplay = nil
            self.activeCategory = nil
            self.candidateCategory = nil
            self.candidateCount = 0
            self.currentNotificationOnsetTime = nil
        }
    }

    private func cancelStableClear() { clearStableToken = nil }

    // MARK: - Eligibility Windows

    private func updateEligibilityWindows(with pred: SoundPrediction) {
        guard let category = pred.category,
              let config = pulseConfigs[category],
              pred.confidence >= config.confidenceThreshold else { return }

        let now = CACurrentMediaTime()
        eligibleUntil[category] = now + config.graceSeconds

        let lastOnset = lastOnsetTime[category] ?? 0
        if (now - lastOnset) > config.onsetMinInterval {
            lastOnsetTime[category] = now
            firePulse(for: category, reason: "\(category.displayName) onset — immediate pulse")
            lastPulseTime[category] = now
        }
    }

    // MARK: - Amplitude → Pulses

    private func handleAmplitude(_ amp: Double) {
        let now = CACurrentMediaTime()
        for category in SoundCategory.allCases {
            guard let config = pulseConfigs[category],
                  let eligible = eligibleUntil[category],
                  now <= eligible else { continue }

            let lastPulse = lastPulseTime[category] ?? 0
            if amp > config.peakThreshold, (now - lastPulse) > config.minPulseInterval {
                lastPulseTime[category] = now
                firePulse(for: category, reason: "Peak > \(config.peakThreshold) within eligibility window")
            }
        }
    }

    private func firePulse(for category: SoundCategory, reason: String) {
        pulseIDs[category] = (pulseIDs[category] ?? 0) + 1

        if hapticsEnabled {
            HapticService.shared.fireHaptic(for: category)
        }

        let intensity = currentDisplay?.intensityLevel
        sessionManager?.logPulse(
            category: category,
            amplitudeValue: currentAmplitude,
            displayedIntensity: intensity,
            animationTriggered: sessionManager?.activeCondition == .animation
        )

        pushTrustEvent(
            label: category.displayName, category: category,
            confidence: latestRaw?.confidence ?? 0,
            triggered: true, reason: reason
        )
    }

    // MARK: - Amplitude Computation

    private nonisolated func computeRMSAmplitude(buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channel = channelData[0]
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<frameLength { let x = channel[i]; sum += x * x }
        let rms = sqrt(sum / Float(frameLength))
        return min(max(Double(rms) * 8.0, 0.0), 1.0)
    }

    // MARK: - Trust Events

    private func pushTrustEvent(label: String, category: SoundCategory?, confidence: Double, triggered: Bool, reason: String) {
        let e = TrustEvent(date: Date(), label: label, category: category, confidence: confidence, triggered: triggered, reason: reason)
        recentTrustEvents.insert(e, at: 0)
        if recentTrustEvents.count > 30 { recentTrustEvents.removeLast() }
    }
}

// MARK: - ResultsObserver

final class ResultsObserver: NSObject, SNResultsObserving {
    private let onResult: (String, Double) -> Void

    init(onResult: @escaping (String, Double) -> Void) {
        self.onResult = onResult
        super.init()
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let res = result as? SNClassificationResult,
              let best = res.classifications.first else { return }
        onResult(best.identifier, Double(best.confidence))
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("❌ SoundAnalysis failed:", error)
    }

    func requestDidComplete(_ request: SNRequest) { }
}
