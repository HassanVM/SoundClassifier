// ExperimentSessionManager.swift
// CREATE NEW FILE: Right-click MasterProject folder → New File → Swift File → "ExperimentSessionManager"

import Foundation
import Combine
import SwiftUI

// MARK: - Session State

enum SessionState: Equatable {
    case idle
    case configured
    case training
    case blockReady(Int)
    case blockActive(Int)
    case blockComplete(Int)
    case sessionComplete
}

// MARK: - Experiment Session Manager

@MainActor
final class ExperimentSessionManager: ObservableObject {

    // MARK: Published State

    @Published var sessionState: SessionState = .idle
    @Published var currentBlock: BlockConfiguration?
    @Published var sessionConfiguration: SessionConfiguration?
    @Published var blockStartTime: Date?

    // Researcher panel selections (persist across sheet dismissals)
    @Published var pendingParticipantID: String = ""
    @Published var pendingOrderIndex: Int = 0
    @Published var pendingRotation: TargetRotation = .rotationA

    // Preview condition for idle/demo mode
    @Published var previewCondition: VisualCondition = .animation
    @Published var elapsedSeconds: Double = 0

    // Logging
    @Published private(set) var detectionLogs: [DetectionEventLog] = []
    @Published private(set) var responseLogs: [ResponseEventLog] = []
    @Published private(set) var pulseLogs: [PulseEventLog] = []
    @Published private(set) var systemLogs: [SystemPerformanceLog] = []

    var trackConfig: TrackConfiguration = .defaultTrack

    private var timer: Timer?
    private var blockConfigurations: [BlockConfiguration] = []

    // MARK: - Session Lifecycle

    func configureSession(_ config: SessionConfiguration) {
        sessionConfiguration = config
        blockConfigurations = (1...3).map { blockNum in
            let targets = config.targetRotation.targets(forBlock: blockNum)
            let condition = config.conditionOrder.condition(forBlock: blockNum)
            let articleID = blockNum <= config.articleAssignment.count
                ? config.articleAssignment[blockNum - 1] : "article\(blockNum)"
            return BlockConfiguration(
                blockNumber: blockNum,
                visualCondition: condition,
                targetCategory1: targets.0,
                targetCategory2: targets.1,
                articleID: articleID
            )
        }
        clearLogs()
        sessionState = .configured
    }

    func configureSession(participantID: String, conditionOrder: ConditionOrder, targetRotation: TargetRotation) {
        let config = SessionConfiguration(
            id: UUID().uuidString.prefix(8).description,
            participantID: participantID,
            conditionOrder: conditionOrder,
            targetRotation: targetRotation,
            articleAssignment: ["article1", "article2", "article3"]
        )
        configureSession(config)
    }

    func startTraining() {
        guard sessionState == .configured else { return }
        sessionState = .training
    }

    func finishTraining() {
        guard sessionState == .training else { return }
        prepareBlock(1)
    }

    func prepareBlock(_ blockNumber: Int) {
        guard blockNumber >= 1 && blockNumber <= 3 else { return }
        currentBlock = blockConfigurations[blockNumber - 1]
        sessionState = .blockReady(blockNumber)
    }

    func startBlock() {
        guard case .blockReady = sessionState else { return }
        blockStartTime = Date()
        elapsedSeconds = 0
        startTimer()
        if case .blockReady(let n) = sessionState {
            sessionState = .blockActive(n)
        }
    }

    func endBlock() {
        guard case .blockActive(let n) = sessionState else { return }
        stopTimer()
        sessionState = .blockComplete(n)
    }

    func proceedAfterBlock() {
        guard case .blockComplete(let n) = sessionState else { return }
        if n < 3 { prepareBlock(n + 1) }
        else { sessionState = .sessionComplete }
    }

    func resetSession() {
        stopTimer()
        sessionState = .idle
        currentBlock = nil
        sessionConfiguration = nil
        blockStartTime = nil
        elapsedSeconds = 0
        clearLogs()
        blockConfigurations = []
    }

    // MARK: - State Helpers

    var activeCondition: VisualCondition? { currentBlock?.visualCondition ?? previewCondition }

    var isBlockActive: Bool {
        if case .blockActive = sessionState { return true }
        return false
    }

    var currentBlockNumber: Int? {
        switch sessionState {
        case .blockReady(let n), .blockActive(let n), .blockComplete(let n): return n
        default: return nil
        }
    }

    var currentTargets: [SoundCategory] {
        guard let block = currentBlock else { return [] }
        return [block.targetCategory1, block.targetCategory2]
    }

    var secondsSinceBlockStart: Double {
        guard let start = blockStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    // MARK: - Intensity Resolution

    func resolveIntensity(for category: SoundCategory, atSessionTime sessionTime: Double, amplitude: Double) -> IntensityLevel {
        if let event = trackConfig.matchEvent(category: category, nearTimestamp: sessionTime) {
            return event.intensity
        }
        return amplitude > 0.30 ? .urgent : .routine
    }

    // MARK: - Response Handling

    func recordTapResponse(displayedCategory: SoundCategory?, displayedIntensity: IntensityLevel?, notificationOnsetTime: Date) {
        guard let block = currentBlock, isBlockActive else { return }
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

    func recordNoResponse(displayedCategory: SoundCategory?, displayedIntensity: IntensityLevel?) {
        guard let block = currentBlock, isBlockActive else { return }
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

    func logDetection(predictedLabel: String, mappedCategory: SoundCategory?, confidence: Double, displayedIntensity: IntensityLevel?, pulseCount: Int) {
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

    func logPulse(category: SoundCategory, amplitudeValue: Double, displayedIntensity: IntensityLevel?, animationTriggered: Bool) {
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

    // MARK: - Data Export

    func exportSessionData() -> SessionDataExport? {
        guard let config = sessionConfiguration else { return nil }
        let blockMetadata = blockConfigurations.map {
            SessionMetadataLog.BlockMetadata(
                blockNumber: $0.blockNumber, condition: $0.visualCondition,
                target1: $0.targetCategory1, target2: $0.targetCategory2, articleID: $0.articleID
            )
        }
        let metadata = SessionMetadataLog(
            sessionID: config.id, participantID: config.participantID,
            dateTime: Date(), conditionOrder: config.conditionOrder,
            targetRotation: config.targetRotation, blockConfigurations: blockMetadata,
            deviceInfo: "\(UIDevice.current.model) - \(UIDevice.current.systemVersion)",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
        return SessionDataExport(
            metadata: metadata, detectionEvents: detectionLogs,
            responseEvents: responseLogs, pulseEvents: pulseLogs,
            systemPerformance: systemLogs, exportDate: Date()
        )
    }

    // MARK: - Block Statistics

    var currentBlockStats: BlockStatistics? {
        guard let block = currentBlock else { return nil }
        let r = responseLogs.filter { $0.blockNumber == block.blockNumber }
        let hits = r.filter { $0.classification == .hit }.count
        let ifa = r.filter { $0.classification == .intensityFalseAlarm }.count
        let cfa = r.filter { $0.classification == .categoryFalseAlarm }.count
        let misses = r.filter { $0.classification == .miss }.count
        let cr = r.filter { $0.classification == .correctRejection }.count
        let rts = r.filter { $0.classification == .hit }.compactMap { $0.reactionTimeMs }
        let meanRT = rts.isEmpty ? nil : rts.reduce(0, +) / Double(rts.count)
        return BlockStatistics(blockNumber: block.blockNumber, condition: block.visualCondition,
                               hits: hits, intensityFalseAlarms: ifa, categoryFalseAlarms: cfa,
                               misses: misses, correctRejections: cr, meanReactionTimeMs: meanRT, totalEvents: r.count)
    }

    // MARK: - Private

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsedSeconds = self?.secondsSinceBlockStart ?? 0 }
        }
    }
    private func stopTimer() { timer?.invalidate(); timer = nil }
    private func clearLogs() { detectionLogs = []; responseLogs = []; pulseLogs = []; systemLogs = [] }
}

// MARK: - Block Statistics

struct BlockStatistics {
    let blockNumber: Int
    let condition: VisualCondition
    let hits: Int
    let intensityFalseAlarms: Int
    let categoryFalseAlarms: Int
    let misses: Int
    let correctRejections: Int
    let meanReactionTimeMs: Double?
    let totalEvents: Int

    var hitRate: Double {
        let total = hits + misses
        return total > 0 ? Double(hits) / Double(total) : 0
    }
    var intensityFARate: Double {
        let total = intensityFalseAlarms + correctRejections
        return total > 0 ? Double(intensityFalseAlarms) / Double(total) : 0
    }
}
