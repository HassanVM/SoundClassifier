// ExperimentSessionManager.swift

import Foundation
import Combine
import SwiftUI

// MARK: - Session State

enum SessionState: Equatable {
    case idle
    // Training modes (standalone, no session)
    case trainingExp1
    case trainingExp2
    // Participant session - Experiment 1
    case exp1BlockReady(Int)
    case exp1BlockActive(Int)
    case exp1BlockComplete(Int)
    case exp1Complete
    // Participant session - Experiment 2
    case exp2PracticeReady
    case exp2PracticeActive
    case exp2BlockReady(Int)
    case exp2BlockActive(Int)
    case exp2BlockComplete(Int)
    case sessionComplete
}

// MARK: - Experiment 1 Trial Phase

enum Exp1TrialPhase: Equatable {
    case idle
    case displaying           // Visual representation shown for 2 seconds
    case respondingCategory   // Display gone, category buttons visible, 5s timer running
    case respondingIntensity  // Category selected, intensity buttons visible, same 5s timer
    case pausing              // 1 second pause before next trial
}

// MARK: - Experiment Session Manager

@MainActor
final class ExperimentSessionManager: ObservableObject {

    // MARK: - Configuration Constants

    let displayDurationSeconds: TimeInterval = 1.0
    let responseWindowSeconds: TimeInterval = 5.0
    let interTrialPauseSeconds: TimeInterval = 1.0

    // MARK: - Published State

    @Published var sessionState: SessionState = .idle
    @Published var currentBlock: BlockConfiguration?
    @Published var sessionConfiguration: SessionConfiguration?
    @Published var blockStartTime: Date?
    @Published var elapsedSeconds: Double = 0

    // Researcher panel pending values
    @Published var pendingParticipantID: String = ""
    @Published var pendingConditionOrderIndex: Int = 0
    @Published var pendingModalityOrderIndex: Int = 0
    @Published var pendingRotation: TargetRotation = .rotationA
    @Published var previewCondition: VisualCondition = .animation

    // MARK: - Experiment 1 Trial State

    @Published private(set) var experiment1Trials: [Experiment1Trial] = []
    @Published private(set) var experiment1TrialIndex: Int = 0
    @Published private(set) var currentExperiment1Trial: Experiment1Trial? = nil
    @Published var exp1TrialPhase: Exp1TrialPhase = .idle
    @Published var exp1SelectedCategory: SoundCategory? = nil
    @Published var exp1SelectedIntensity: IntensityLevel? = nil
    @Published var exp1ResponseTimeRemaining: Double = 5.0
    @Published var exp1IsPractice: Bool = false

    /// Pulse IDs for driving animations in the grid (Experiment 1)
    @Published var exp1PulseIDs: [SoundCategory: Int] = {
        Dictionary(uniqueKeysWithValues: SoundCategory.allCases.map { ($0, 0) })
    }()

    var exp1ResponseReady: Bool { exp1SelectedCategory != nil && exp1SelectedIntensity != nil }

    // Timing for separate category/intensity reaction times
    private var displayDisappearedTime: Date? = nil
    private var categoryTapTime: Date? = nil

    // Timers
    private var displayTimer: Timer?
    private var responseTimer: Timer?
    private var responseCountdownTimer: Timer?
    private var pauseTimer: Timer?
    private var animationPulseTimer: Timer?

    // MARK: - Experiment 2 State

    @Published var activeModality: FeedbackModality = .visualOnly

    // MARK: - Logging

    @Published private(set) var exp1ResponseLogs: [Experiment1ResponseLog] = []
    @Published private(set) var detectionLogs: [DetectionEventLog] = []
    @Published private(set) var responseLogs: [ResponseEventLog] = []
    @Published private(set) var pulseLogs: [PulseEventLog] = []
    @Published private(set) var systemLogs: [SystemPerformanceLog] = []

    var trackConfig: TrackConfiguration = .defaultTrack
    private var timer: Timer?
    private var exp1BlockConfigs: [BlockConfiguration] = []
    private var exp2BlockConfigs: [BlockConfiguration] = []

    /// One-tap setup from the home screen participant picker.
    /// All counterbalancing is pre-calculated — no manual configuration needed.
    func configureAndStart(assignment: CounterbalancingAssignment) {
        configureSession(
            participantID: assignment.participantID,
            conditionOrderIndex: assignment.conditionOrderIndex,
            modalityOrderIndex: assignment.modalityOrderIndex,
            targetRotation: assignment.targetRotation
        )
        // Go directly to Experiment 1 Block 1
        prepareExp1Block(1)
    }

    // MARK: - Session Setup

    func configureSession(participantID: String,
                          conditionOrderIndex: Int,
                          modalityOrderIndex: Int,
                          targetRotation: TargetRotation) {
        let conditionOrder = ConditionOrder.allOrders[conditionOrderIndex]
        let modalityOrder  = ModalityOrder.allOrders[modalityOrderIndex]
        let config = SessionConfiguration(
            id: UUID().uuidString.prefix(8).description,
            participantID: participantID,
            conditionOrder: conditionOrder,
            modalityOrder: modalityOrder,
            targetRotation: targetRotation,
            articleAssignment: ["article1", "article2", "article3"]
        )
        sessionConfiguration = config

        // Build Experiment 1 blocks (3 × visual condition)
        exp1BlockConfigs = (1...3).map { n in
            var b = BlockConfiguration(blockNumber: n, experimentPhase: .experiment1)
            b.visualCondition = conditionOrder.condition(forBlock: n)
            return b
        }

        // Build Experiment 2 blocks (3 × modality, always animation)
        exp2BlockConfigs = (1...3).map { n in
            var b = BlockConfiguration(blockNumber: n, experimentPhase: .experiment2)
            b.visualCondition = .animation  // Always animation
            b.feedbackModality = modalityOrder.modality(forBlock: n)
            let targets = targetRotation.targets(forBlock: n)
            b.targetCategory1 = targets.0
            b.targetCategory2 = targets.1
            b.articleID = config.articleAssignment[n - 1]
            return b
        }

        clearLogs()
        // State will be set by the caller (configureAndStart → prepareExp1Block)
    }

    // MARK: - Experiment 1 Block Management

    func prepareExp1Block(_ n: Int) {
        guard n >= 1, n <= 3 else { return }
        currentBlock = exp1BlockConfigs[n - 1]
        experiment1Trials = Experiment1Trial.trials(forBlock: n,
                                                    condition: exp1BlockConfigs[n - 1].visualCondition)
        experiment1TrialIndex = 0
        currentExperiment1Trial = nil
        exp1TrialPhase = .idle
        exp1SelectedCategory = nil
        exp1SelectedIntensity = nil
        exp1IsPractice = false
        sessionState = .exp1BlockReady(n)
    }

    func startExp1Block() {
        guard case .exp1BlockReady(let n) = sessionState else { return }
        blockStartTime = Date()
        elapsedSeconds = 0
        startTimer()
        sessionState = .exp1BlockActive(n)
        // Start the first trial automatically
        startNextTrial()
    }

    // MARK: - Experiment 1 Automated Trial Flow

    /// Starts the next trial in the automated sequence
    func startNextTrial() {
        guard case .exp1BlockActive = sessionState else { return }
        guard experiment1TrialIndex < experiment1Trials.count else {
            // All trials done
            endExp1Block()
            return
        }

        let trial = experiment1Trials[experiment1TrialIndex]
        currentExperiment1Trial = trial
        exp1SelectedCategory = nil
        exp1SelectedIntensity = nil
        exp1TrialPhase = .displaying
        displayDisappearedTime = nil
        categoryTapTime = nil

        // Drive animation pulses for the active cell
        exp1PulseIDs[trial.shownCategory, default: 0] += 1

        // Fire animation pulses during the 2-second display window
        if currentBlock?.visualCondition == .animation {
            let cat = trial.shownCategory
            // Fire pulses throughout the 2-second window
            let pulseTimes = [0.15, 0.35, 0.55, 0.75]
            for delay in pulseTimes {
                if delay < displayDurationSeconds {
                    animationPulseTimer = nil // clear any previous
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        guard let self, self.exp1TrialPhase == .displaying,
                              self.currentExperiment1Trial?.shownCategory == cat else { return }
                        self.exp1PulseIDs[cat, default: 0] += 1
                    }
                }
            }
        }

        // Schedule display disappearance after 2 seconds
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: displayDurationSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.onDisplayExpired()
            }
        }
    }

    /// Called when the 2-second display window ends
    private func onDisplayExpired() {
        guard exp1TrialPhase == .displaying else { return }
        exp1TrialPhase = .respondingCategory
        displayDisappearedTime = Date()
        exp1ResponseTimeRemaining = responseWindowSeconds

        // Start the 5-second response countdown
        responseCountdownTimer?.invalidate()
        responseCountdownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let disappeared = self.displayDisappearedTime else { return }
                let elapsed = Date().timeIntervalSince(disappeared)
                self.exp1ResponseTimeRemaining = max(0, self.responseWindowSeconds - elapsed)
            }
        }

        // Schedule timeout after 5 seconds
        responseTimer?.invalidate()
        responseTimer = Timer.scheduledTimer(withTimeInterval: responseWindowSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.onResponseTimeout()
            }
        }
    }

    /// Called when the participant taps a category button
    func selectCategory(_ category: SoundCategory) {
        guard exp1TrialPhase == .respondingCategory else { return }
        exp1SelectedCategory = category
        categoryTapTime = Date()
        exp1TrialPhase = .respondingIntensity
        // Response timer keeps running — no reset
    }

    /// Called when the participant taps an intensity button
    func selectIntensity(_ intensity: IntensityLevel) {
        guard exp1TrialPhase == .respondingIntensity else { return }
        exp1SelectedIntensity = intensity
        // Auto-submit on intensity selection
        submitResponse(timedOut: false)
    }

    /// Called when the 5-second response window expires
    private func onResponseTimeout() {
        responseCountdownTimer?.invalidate()
        guard exp1TrialPhase == .respondingCategory || exp1TrialPhase == .respondingIntensity else { return }
        submitResponse(timedOut: true)
    }

    /// Record the response and move to pause
    private func submitResponse(timedOut: Bool) {
        displayTimer?.invalidate()
        responseTimer?.invalidate()
        responseCountdownTimer?.invalidate()

        guard let trial = currentExperiment1Trial else { return }

        let catRT: Double?
        let intRT: Double?
        let totalRT: Double

        if let disappeared = displayDisappearedTime {
            totalRT = Date().timeIntervalSince(disappeared) * 1000

            if let catTime = categoryTapTime {
                catRT = catTime.timeIntervalSince(disappeared) * 1000
                if !timedOut, exp1SelectedIntensity != nil {
                    intRT = Date().timeIntervalSince(catTime) * 1000
                } else {
                    intRT = nil
                }
            } else {
                catRT = nil
                intRT = nil
            }
        } else {
            totalRT = 0
            catRT = nil
            intRT = nil
        }

        // Only log scored trials, not practice
        if !exp1IsPractice {
            let log = Experiment1ResponseLog(
                trial: trial,
                respondedCategory: timedOut ? exp1SelectedCategory : exp1SelectedCategory,
                respondedIntensity: timedOut ? exp1SelectedIntensity : exp1SelectedIntensity,
                categoryReactionTimeMs: catRT,
                intensityReactionTimeMs: intRT,
                totalReactionTimeMs: totalRT,
                timedOut: timedOut
            )
            exp1ResponseLogs.append(log)
        }

        // Clear trial state and start pause
        currentExperiment1Trial = nil
        exp1TrialPhase = .pausing
        experiment1TrialIndex += 1

        // 1-second pause, then next trial
        pauseTimer?.invalidate()
        pauseTimer = Timer.scheduledTimer(withTimeInterval: interTrialPauseSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.exp1TrialPhase = .idle
                self?.exp1SelectedCategory = nil
                self?.exp1SelectedIntensity = nil
                self?.startNextTrial()
            }
        }
    }

    func endExp1Block() {
        displayTimer?.invalidate()
        responseTimer?.invalidate()
        responseCountdownTimer?.invalidate()
        pauseTimer?.invalidate()
        stopTimer()
        exp1TrialPhase = .idle
        currentExperiment1Trial = nil

        guard let block = currentBlock, block.experimentPhase == .experiment1 else { return }
        sessionState = .exp1BlockComplete(block.blockNumber)
    }

    func proceedAfterExp1Block() {
        guard case .exp1BlockComplete(let n) = sessionState else { return }
        if n < 3 {
            prepareExp1Block(n + 1)
        } else {
            sessionState = .exp1Complete
        }
    }

    // MARK: - Experiment 2 Practice Block

    func prepareExp2Practice() {
        guard sessionState == .exp1Complete else { return }
        sessionState = .exp2PracticeReady
    }

    func startExp2Practice() {
        guard sessionState == .exp2PracticeReady else { return }
        sessionState = .exp2PracticeActive
        // Practice block uses animation, visual+haptic modality
        var practiceBlock = BlockConfiguration(blockNumber: 0, experimentPhase: .experiment2)
        practiceBlock.visualCondition = .animation
        practiceBlock.feedbackModality = .visualHaptic
        currentBlock = practiceBlock
        activeModality = .visualHaptic
        blockStartTime = Date()
        elapsedSeconds = 0
        startTimer()
    }

    func endExp2Practice() {
        stopTimer()
        currentBlock = nil
        prepareExp2Block(1)
    }

    // MARK: - Experiment 2 Block Management

    func prepareExp2Block(_ n: Int) {
        guard n >= 1, n <= 3 else { return }
        let blockConfig = exp2BlockConfigs[n - 1]
        currentBlock = blockConfig
        activeModality = blockConfig.feedbackModality
        sessionState = .exp2BlockReady(n)
    }

    func startExp2Block() {
        guard case .exp2BlockReady(let n) = sessionState else { return }
        blockStartTime = Date()
        elapsedSeconds = 0
        startTimer()
        sessionState = .exp2BlockActive(n)
    }

    func endExp2Block() {
        stopTimer()
        guard let block = currentBlock, block.experimentPhase == .experiment2 else { return }
        sessionState = .exp2BlockComplete(block.blockNumber)
    }

    func proceedAfterExp2Block() {
        guard case .exp2BlockComplete(let n) = sessionState else { return }
        if n < 3 {
            prepareExp2Block(n + 1)
        } else {
            sessionState = .sessionComplete
        }
    }

    // MARK: - Reset

    func resetSession() {
        displayTimer?.invalidate()
        responseTimer?.invalidate()
        responseCountdownTimer?.invalidate()
        pauseTimer?.invalidate()
        stopTimer()
        sessionState = .idle
        currentBlock = nil
        sessionConfiguration = nil
        blockStartTime = nil
        elapsedSeconds = 0
        experiment1Trials = []
        experiment1TrialIndex = 0
        currentExperiment1Trial = nil
        exp1TrialPhase = .idle
        exp1SelectedCategory = nil
        exp1SelectedIntensity = nil
        exp1IsPractice = false
        exp1BlockConfigs = []
        exp2BlockConfigs = []
        clearLogs()
    }

    // MARK: - State Helpers

    var activeCondition: VisualCondition? { currentBlock?.visualCondition ?? previewCondition }
    var currentExperimentPhase: ExperimentPhase? { currentBlock?.experimentPhase }

    var isExp1BlockActive: Bool {
        if case .exp1BlockActive = sessionState { return true }
        return false
    }

    var isExp2BlockActive: Bool {
        if case .exp2BlockActive = sessionState { return true }
        return false
    }

    var isBlockActive: Bool { isExp1BlockActive || isExp2BlockActive }

    var secondsSinceBlockStart: Double {
        guard let start = blockStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    var currentTargets: [SoundCategory] {
        guard let block = currentBlock else { return [] }
        return [block.targetCategory1, block.targetCategory2]
    }

    // MARK: - Intensity Resolution (Experiment 2)

    func resolveIntensity(for category: SoundCategory,
                          atSessionTime sessionTime: Double,
                          amplitude: Double) -> IntensityLevel {
        if let event = trackConfig.matchEvent(category: category, nearTimestamp: sessionTime) {
            return event.intensity
        }
        return amplitude > 0.15 ? .urgent : .routine
    }

    // MARK: - Experiment 2 Response Handling

    func recordTapResponse(displayedCategory: SoundCategory?,
                           displayedIntensity: IntensityLevel?,
                           notificationOnsetTime: Date) {
        guard let block = currentBlock, isExp2BlockActive else { return }
        let reactionTimeMs = Date().timeIntervalSince(notificationOnsetTime) * 1000
        let isTarget = displayedCategory.map { block.isTarget($0) } ?? false
        let classification = ResponseClassification.classify(
            didTap: true,
            category: displayedCategory ?? .knocking,
            intensity: displayedIntensity ?? .routine,
            block: block
        )
        responseLogs.append(ResponseEventLog(
            sessionTimestamp: secondsSinceBlockStart,
            displayedCategory: displayedCategory,
            displayedIntensity: displayedIntensity,
            isTarget: isTarget,
            reactionTimeMs: reactionTimeMs,
            didTap: true,
            classification: classification,
            activeCondition: block.visualCondition,
            blockNumber: block.blockNumber
        ))
    }

    func recordNoResponse(displayedCategory: SoundCategory?,
                          displayedIntensity: IntensityLevel?) {
        guard let block = currentBlock, isExp2BlockActive else { return }
        let isTarget = displayedCategory.map { block.isTarget($0) } ?? false
        let classification = ResponseClassification.classify(
            didTap: false,
            category: displayedCategory ?? .knocking,
            intensity: displayedIntensity ?? .routine,
            block: block
        )
        responseLogs.append(ResponseEventLog(
            sessionTimestamp: secondsSinceBlockStart,
            displayedCategory: displayedCategory,
            displayedIntensity: displayedIntensity,
            isTarget: isTarget,
            reactionTimeMs: nil,
            didTap: false,
            classification: classification,
            activeCondition: block.visualCondition,
            blockNumber: block.blockNumber
        ))
    }

    // MARK: - Logging

    func logDetection(predictedLabel: String, mappedCategory: SoundCategory?,
                      confidence: Double, displayedIntensity: IntensityLevel?, pulseCount: Int) {
        guard let block = currentBlock else { return }
        detectionLogs.append(DetectionEventLog(
            sessionTimestamp: secondsSinceBlockStart,
            predictedLabel: predictedLabel,
            mappedCategory: mappedCategory,
            confidence: confidence,
            displayedIntensity: displayedIntensity,
            activeCondition: block.visualCondition,
            currentTargets: currentTargets,
            pulseCount: pulseCount
        ))
    }

    func logPulse(category: SoundCategory, amplitudeValue: Double,
                  displayedIntensity: IntensityLevel?, animationTriggered: Bool) {
        guard let block = currentBlock else { return }
        pulseLogs.append(PulseEventLog(
            sessionTimestamp: secondsSinceBlockStart,
            category: category,
            amplitudeValue: amplitudeValue,
            displayedIntensity: displayedIntensity,
            animationTriggered: block.visualCondition == .animation,
            activeCondition: block.visualCondition
        ))
    }

    func logSystemEvent(latencyMs: Double? = nil, error: String? = nil) {
        systemLogs.append(SystemPerformanceLog(
            classificationLatencyMs: latencyMs,
            batteryLevel: UIDevice.current.batteryLevel,
            errorMessage: error
        ))
    }

    // MARK: - Block Statistics (Experiment 2)

    var currentBlockStats: BlockStatistics? {
        guard let block = currentBlock, block.experimentPhase == .experiment2 else { return nil }
        let r = responseLogs.filter { $0.blockNumber == block.blockNumber }
        let hits = r.filter { $0.classification == .hit }.count
        let ifa  = r.filter { $0.classification == .intensityFalseAlarm }.count
        let cfa  = r.filter { $0.classification == .categoryFalseAlarm }.count
        let miss = r.filter { $0.classification == .miss }.count
        let cr   = r.filter { $0.classification == .correctRejection }.count
        let rts  = r.filter { $0.classification == .hit }.compactMap { $0.reactionTimeMs }
        let meanRT = rts.isEmpty ? nil : rts.reduce(0, +) / Double(rts.count)
        return BlockStatistics(
            blockNumber: block.blockNumber, condition: block.visualCondition,
            modality: block.feedbackModality,
            hits: hits, intensityFalseAlarms: ifa, categoryFalseAlarms: cfa,
            misses: miss, correctRejections: cr,
            meanReactionTimeMs: meanRT, totalEvents: r.count
        )
    }

    // MARK: - Experiment 1 Stats

    var exp1BlockAccuracy: Double? {
        guard let block = currentBlock, block.experimentPhase == .experiment1 else { return nil }
        let logs = exp1ResponseLogs.filter { $0.blockNumber == block.blockNumber }
        guard !logs.isEmpty else { return nil }
        return Double(logs.filter { $0.fullyCorrect }.count) / Double(logs.count)
    }

    // MARK: - Data Export

    func exportSessionData() -> SessionDataExport? {
        guard let config = sessionConfiguration else { return nil }
        let exp1Metadata = exp1BlockConfigs.map {
            SessionMetadataLog.BlockMetadata(
                blockNumber: $0.blockNumber, condition: $0.visualCondition,
                target1: $0.targetCategory1, target2: $0.targetCategory2, articleID: $0.articleID
            )
        }
        let metadata = SessionMetadataLog(
            sessionID: config.id, participantID: config.participantID,
            dateTime: Date(), conditionOrder: config.conditionOrder,
            targetRotation: config.targetRotation, blockConfigurations: exp1Metadata,
            deviceInfo: "\(UIDevice.current.model) - \(UIDevice.current.systemVersion)",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
        return SessionDataExport(
            metadata: metadata, experiment1Responses: exp1ResponseLogs,
            detectionEvents: detectionLogs,
            responseEvents: responseLogs, pulseEvents: pulseLogs,
            systemPerformance: systemLogs, exportDate: Date()
        )
    }

    // MARK: - Private Helpers

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.elapsedSeconds = self?.secondsSinceBlockStart ?? 0
            }
        }
    }
    private func stopTimer() { timer?.invalidate(); timer = nil }
    private func clearLogs() {
        exp1ResponseLogs = []
        detectionLogs = []
        responseLogs = []
        pulseLogs = []
        systemLogs = []
    }
}
