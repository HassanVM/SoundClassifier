// SoundClassifierService.swift
import AVFoundation
import SoundAnalysis
import Combine
import UIKit

// MARK: - Models

struct SoundPrediction: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let confidence: Double
    let date: Date
}

enum ConfidenceBucket: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

struct TrustEvent: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let confidence: Double
    let triggered: Bool
    let reason: String
}

struct UserFeedback: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let confidence: Double
    let verdict: Verdict

    enum Verdict: String {
        case correct = "Correct"
        case wrong = "Wrong"
    }
}

// MARK: - Service

final class SoundClassifierService: NSObject, ObservableObject {

    @Published var isListening: Bool = false
    @Published var latestRaw: SoundPrediction?
    @Published var stableDisplay: SoundPrediction?
    @Published var lastUpdate: Date?

    @Published var knockPulseID: Int = 0
    @Published var dogPulseID: Int = 0
    @Published var babyPulseID: Int = 0
    @Published var alarmPulseID: Int = 0

    @Published var doorbellDetected: Bool = false
    @Published var doorbellPulseID: Int = 0

    @Published var hapticsEnabled: Bool = true
    @Published var recentTrustEvents: [TrustEvent] = []
    @Published var feedbackLog: [UserFeedback] = []

    private let audioEngine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer?
    private var request: SNClassifySoundRequest?
    private var observer: ResultsObserver?

    // Awareness card tuning
    private let displayThreshold: Double = 0.65
    private let minConsecutive: Int = 2
    private let holdDuration: TimeInterval = 1.0

    private var candidateLabel: String?
    private var candidateCount: Int = 0
    private var clearStableToken: UUID?

    // MARK: Knock pulse tuning
    private var knockEligibleUntil: CFTimeInterval = 0
    private var lastKnockPulseTime: CFTimeInterval = 0

    // onset pulse gating (knock)
    private var lastKnockOnsetTime: CFTimeInterval = 0
    private let knockOnsetMinInterval: Double = 0.35

    private let knockPeakThreshold: Double = 0.20
    private let knockMinPulseInterval: Double = 0.10
    private let knockGraceSeconds: Double = 1.00

    // Suppress knock right AFTER doorbell overlay ends
    private var suppressKnockUntil: CFTimeInterval = 0
    private let suppressKnockAfterDoorbell: Double = 1.20

    // Dog pulse tuning
    private var dogEligibleUntil: CFTimeInterval = 0
    private var lastDogPulseTime: CFTimeInterval = 0
    private let dogPeakThreshold: Double = 0.20
    private let dogMinPulseInterval: Double = 0.14
    private let dogGraceSeconds: Double = 1.20

    // Baby cry pulse tuning
    private var babyEligibleUntil: CFTimeInterval = 0
    private var lastBabyPulseTime: CFTimeInterval = 0
    private let babyPeakThreshold: Double = 0.18
    private let babyMinPulseInterval: Double = 0.14
    private let babyGraceSeconds: Double = 1.40

    // Alarm/Siren pulse tuning
    private var alarmEligibleUntil: CFTimeInterval = 0
    private var lastAlarmPulseTime: CFTimeInterval = 0
    private let alarmPeakThreshold: Double = 0.18
    private let alarmMinPulseInterval: Double = 0.12
    private let alarmGraceSeconds: Double = 1.60

    // Alarm onset pulse gating
    private var lastAlarmOnsetTime: CFTimeInterval = 0
    private let alarmOnsetMinInterval: Double = 0.45

    // Doorbell
    private let doorbellThreshold: Double = 0.80
    private let doorbellCooldown: TimeInterval = 3.0
    private var lastDoorbellDate: Date?

    private let doorbellOverlayDuration: TimeInterval = 4.0
    private var doorbellHideToken = UUID()

    // MARK: Public API

    func start() {
        guard !isListening else { return }
        do {
            resetState()
            try configureAudioSession()
            try startEngineAndAnalyzer()
            DispatchQueue.main.async { self.isListening = true }
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

        DispatchQueue.main.async {
            self.isListening = false
            self.resetState()
        }
    }

    func confidenceBucket(for c: Double) -> ConfidenceBucket {
        if c >= 0.85 { return .high }
        if c >= 0.70 { return .medium }
        return .low
    }

    func addFeedback(verdict: UserFeedback.Verdict) {
        guard let shown = stableDisplay ?? latestRaw else { return }
        let item = UserFeedback(date: Date(), label: shown.label, confidence: shown.confidence, verdict: verdict)
        DispatchQueue.main.async {
            self.feedbackLog.insert(item, at: 0)
            if self.feedbackLog.count > 50 { self.feedbackLog.removeLast() }
        }
    }

    // ContentView uses this to prevent the post-doorbell knock flash
    func isKnockSuppressedNow() -> Bool {
        CACurrentMediaTime() < suppressKnockUntil
    }

    // MARK: Label helpers

    func isKnockLikeLabel(_ label: String) -> Bool {
        let s = label.lowercased()
        return s == "knock"
            || s.contains("knocking")
            || s.contains("tap")
            || s.contains("tapping")
            || s.contains("thump")
            || s.contains("impact")
            || s.contains("bang")
            || s.contains("door")
    }

    func isDogLikeLabel(_ label: String) -> Bool {
        let s = label.lowercased()
        return s.contains("dog") || s.contains("bark")
    }

    func isBabyLikeLabel(_ label: String) -> Bool {
        let s = label.lowercased()
        return s.contains("baby") || s.contains("cry")
    }

    func isAlarmLikeLabel(_ label: String) -> Bool {
        let s = label.lowercased()
        return s.contains("siren")
            || s.contains("alarm")
            || s.contains("ambulance")
            || s.contains("police")
            || s.contains("fire_truck")
            || s.contains("fire truck")
            || s.contains("fire")
            || s.contains("emergency")
    }

    // MARK: Internals

    private func resetState() {
        latestRaw = nil
        stableDisplay = nil
        lastUpdate = nil

        candidateLabel = nil
        candidateCount = 0
        clearStableToken = nil

        knockPulseID = 0
        dogPulseID = 0
        babyPulseID = 0
        alarmPulseID = 0

        knockEligibleUntil = 0
        dogEligibleUntil = 0
        babyEligibleUntil = 0
        alarmEligibleUntil = 0

        lastKnockPulseTime = 0
        lastDogPulseTime = 0
        lastBabyPulseTime = 0
        lastAlarmPulseTime = 0

        lastKnockOnsetTime = 0
        lastAlarmOnsetTime = 0

        suppressKnockUntil = 0

        doorbellDetected = false
        doorbellPulseID = 0
        lastDoorbellDate = nil
        doorbellHideToken = UUID()
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                                mode: .default,
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
            let pred = SoundPrediction(label: label, confidence: confidence, date: Date())

            DispatchQueue.main.async {
                self.lastUpdate = pred.date
                self.latestRaw = pred

                self.updateStableDisplay(with: pred)

                // Doorbell early
                self.handleDoorbell(with: pred)

                // Other gating
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
            self.handleAmplitude(amp)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    // MARK: Awareness stability

    private func updateStableDisplay(with pred: SoundPrediction) {
        guard pred.confidence >= displayThreshold else {
            scheduleStableClear()
            return
        }

        if pred.label == candidateLabel {
            candidateCount += 1
        } else {
            candidateLabel = pred.label
            candidateCount = 1
        }

        if candidateCount >= minConsecutive {
            stableDisplay = pred
            cancelStableClear()
        }
    }

    private func scheduleStableClear() {
        guard stableDisplay != nil else { return }

        let token = UUID()
        clearStableToken = token

        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) { [weak self] in
            guard let self else { return }
            if self.clearStableToken == token {
                self.stableDisplay = nil
                self.candidateLabel = nil
                self.candidateCount = 0
            }
        }
    }

    private func cancelStableClear() {
        clearStableToken = nil
    }

    // MARK: Eligibility windows (UPDATED)

    private func updateEligibilityWindows(with pred: SoundPrediction) {
        let s = pred.label.lowercased()
        let now = CACurrentMediaTime()

        // While doorbell overlay is active, ignore other windows/pulses
        if doorbellDetected { return }

        // Knock: if suppressed, don't open window or onset pulse
        if isKnockLikeLabel(s), pred.confidence >= 0.25 {

            if now < suppressKnockUntil {
                pushTrustEvent(label: "knock",
                               confidence: pred.confidence,
                               triggered: false,
                               reason: "Knock suppressed right after doorbell")
                return
            }

            knockEligibleUntil = now + knockGraceSeconds

            // immediate onset pulse
            if (now - lastKnockOnsetTime) > knockOnsetMinInterval {
                lastKnockOnsetTime = now
                fireKnockPulse(reason: "Knock onset (label detected) — immediate pulse")
                lastKnockPulseTime = now
            }
        }

        // Dog
        if isDogLikeLabel(s), pred.confidence >= 0.30 {
            dogEligibleUntil = now + dogGraceSeconds
        }

        // Baby
        if isBabyLikeLabel(s), pred.confidence >= 0.30 {
            babyEligibleUntil = now + babyGraceSeconds
        }

        // Alarm/Siren + onset pulse
        if isAlarmLikeLabel(s), pred.confidence >= 0.25 {
            alarmEligibleUntil = now + alarmGraceSeconds

            if (now - lastAlarmOnsetTime) > alarmOnsetMinInterval {
                lastAlarmOnsetTime = now

                DispatchQueue.main.async {
                    self.alarmPulseID += 1
                    if self.hapticsEnabled {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    }
                    self.pushTrustEvent(label: "siren_alarm",
                                        confidence: pred.confidence,
                                        triggered: true,
                                        reason: "Alarm onset (label detected) — immediate pulse")
                }

                lastAlarmPulseTime = now
            }
        }
    }

    // MARK: Amplitude -> pulses

    private func handleAmplitude(_ amp: Double) {
        let now = CACurrentMediaTime()

        // While doorbell overlay is active, ignore other pulses
        if doorbellDetected { return }

        // Knock pulses (but suppressed after doorbell)
        if now <= knockEligibleUntil, now >= suppressKnockUntil {
            if amp > knockPeakThreshold, (now - lastKnockPulseTime) > knockMinPulseInterval {
                lastKnockPulseTime = now
                fireKnockPulse(reason: "Peak > \(knockPeakThreshold) within knock eligibility window")
            }
        }

        // Dog pulses
        if now <= dogEligibleUntil {
            if amp > dogPeakThreshold, (now - lastDogPulseTime) > dogMinPulseInterval {
                lastDogPulseTime = now
                DispatchQueue.main.async {
                    self.dogPulseID += 1
                    if self.hapticsEnabled {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    self.pushTrustEvent(label: "dog_bark",
                                        confidence: self.latestRaw?.confidence ?? 0,
                                        triggered: true,
                                        reason: "Peak > \(self.dogPeakThreshold) within dog eligibility window")
                }
            }
        }

        // Baby pulses
        if now <= babyEligibleUntil {
            if amp > babyPeakThreshold, (now - lastBabyPulseTime) > babyMinPulseInterval {
                lastBabyPulseTime = now
                DispatchQueue.main.async {
                    self.babyPulseID += 1
                    if self.hapticsEnabled {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    self.pushTrustEvent(label: "baby_cry",
                                        confidence: self.latestRaw?.confidence ?? 0,
                                        triggered: true,
                                        reason: "Peak > \(self.babyPeakThreshold) within baby eligibility window")
                }
            }
        }

        // Alarm pulses
        if now <= alarmEligibleUntil {
            if amp > alarmPeakThreshold, (now - lastAlarmPulseTime) > alarmMinPulseInterval {
                lastAlarmPulseTime = now
                DispatchQueue.main.async {
                    self.alarmPulseID += 1
                    if self.hapticsEnabled {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    }
                    self.pushTrustEvent(label: "siren_alarm",
                                        confidence: self.latestRaw?.confidence ?? 0,
                                        triggered: true,
                                        reason: "Peak > \(self.alarmPeakThreshold) within alarm eligibility window")
                }
            }
        }
    }

    private func fireKnockPulse(reason: String) {
        DispatchQueue.main.async {
            self.knockPulseID += 1
            if self.hapticsEnabled {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
            self.pushTrustEvent(label: "knock",
                                confidence: self.latestRaw?.confidence ?? 0,
                                triggered: true,
                                reason: reason)
        }
    }

    private func computeRMSAmplitude(buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channel = channelData[0]
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        var sum: Float = 0
        for i in 0..<frameLength {
            let x = channel[i]
            sum += x * x
        }
        let rms = sqrt(sum / Float(frameLength))
        return min(max(Double(rms) * 8.0, 0.0), 1.0)
    }

    // MARK: Doorbell

    private func handleDoorbell(with pred: SoundPrediction) {
        let normalized = pred.label.lowercased()
        let isDoorbellLike =
            normalized.contains("doorbell") ||
            normalized.contains("door bell") ||
            normalized.contains("door_bell")

        guard isDoorbellLike else { return }

        guard pred.confidence >= doorbellThreshold else {
            pushTrustEvent(label: pred.label, confidence: pred.confidence, triggered: false,
                           reason: "Doorbell-like label but confidence < \(doorbellThreshold)")
            return
        }

        let now = Date()
        if let last = lastDoorbellDate, now.timeIntervalSince(last) < doorbellCooldown {
            pushTrustEvent(label: pred.label, confidence: pred.confidence, triggered: false,
                           reason: "Doorbell cooldown active (\(Int(doorbellCooldown))s)")
            return
        }

        lastDoorbellDate = now
        triggerDoorbellFeedback(confidence: pred.confidence)
    }

    private func triggerDoorbellFeedback(confidence: Double) {
        if hapticsEnabled {
            let gen = UINotificationFeedbackGenerator()
            gen.prepare()
            gen.notificationOccurred(.success)
        }

        doorbellPulseID += 1
        doorbellDetected = true

        pushTrustEvent(label: "doorbell", confidence: confidence, triggered: true,
                       reason: "Label match + confidence ≥ \(doorbellThreshold) + cooldown OK")

        let token = UUID()
        doorbellHideToken = token

        DispatchQueue.main.asyncAfter(deadline: .now() + doorbellOverlayDuration) { [weak self] in
            guard let self else { return }
            guard self.doorbellHideToken == token else { return }

            // overlay ends
            self.doorbellDetected = false

            // Start knock suppression AFTER overlay ends (this is the key fix)
            self.suppressKnockUntil = CACurrentMediaTime() + self.suppressKnockAfterDoorbell
        }
    }

    private func pushTrustEvent(label: String, confidence: Double, triggered: Bool, reason: String) {
        let e = TrustEvent(date: Date(), label: label, confidence: confidence, triggered: triggered, reason: reason)
        recentTrustEvents.insert(e, at: 0)
        if recentTrustEvents.count > 20 { recentTrustEvents.removeLast() }
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
        print(" SoundAnalysis failed:", error)
    }

    func requestDidComplete(_ request: SNRequest) { }
}
