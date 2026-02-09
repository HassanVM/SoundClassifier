// LogModels.swift
// CREATE NEW FILE: Right-click MasterProject folder → New File → Swift File → "LogModels"

import Foundation

// MARK: - Detection Event Log

struct DetectionEventLog: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let sessionTimestamp: Double
    let predictedLabel: String
    let mappedCategory: SoundCategory?
    let confidence: Double
    let displayedIntensity: IntensityLevel?
    let activeCondition: VisualCondition
    let currentTargets: [SoundCategory]
    let pulseCount: Int
    let matchedGroundTruthID: UUID?

    init(
        sessionTimestamp: Double,
        predictedLabel: String,
        mappedCategory: SoundCategory?,
        confidence: Double,
        displayedIntensity: IntensityLevel?,
        activeCondition: VisualCondition,
        currentTargets: [SoundCategory],
        pulseCount: Int,
        matchedGroundTruthID: UUID? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.sessionTimestamp = sessionTimestamp
        self.predictedLabel = predictedLabel
        self.mappedCategory = mappedCategory
        self.confidence = confidence
        self.displayedIntensity = displayedIntensity
        self.activeCondition = activeCondition
        self.currentTargets = currentTargets
        self.pulseCount = pulseCount
        self.matchedGroundTruthID = matchedGroundTruthID
    }
}

// MARK: - Response Event Log

struct ResponseEventLog: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let sessionTimestamp: Double
    let displayedCategory: SoundCategory?
    let displayedIntensity: IntensityLevel?
    let isTarget: Bool
    let reactionTimeMs: Double?
    let didTap: Bool
    let classification: ResponseClassification
    let activeCondition: VisualCondition
    let blockNumber: Int

    init(
        sessionTimestamp: Double,
        displayedCategory: SoundCategory?,
        displayedIntensity: IntensityLevel?,
        isTarget: Bool,
        reactionTimeMs: Double?,
        didTap: Bool,
        classification: ResponseClassification,
        activeCondition: VisualCondition,
        blockNumber: Int
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.sessionTimestamp = sessionTimestamp
        self.displayedCategory = displayedCategory
        self.displayedIntensity = displayedIntensity
        self.isTarget = isTarget
        self.reactionTimeMs = reactionTimeMs
        self.didTap = didTap
        self.classification = classification
        self.activeCondition = activeCondition
        self.blockNumber = blockNumber
    }
}

// MARK: - Pulse Event Log

struct PulseEventLog: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let sessionTimestamp: Double
    let category: SoundCategory
    let amplitudeValue: Double
    let displayedIntensity: IntensityLevel?
    let animationTriggered: Bool
    let activeCondition: VisualCondition

    init(
        sessionTimestamp: Double,
        category: SoundCategory,
        amplitudeValue: Double,
        displayedIntensity: IntensityLevel?,
        animationTriggered: Bool,
        activeCondition: VisualCondition
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.sessionTimestamp = sessionTimestamp
        self.category = category
        self.amplitudeValue = amplitudeValue
        self.displayedIntensity = displayedIntensity
        self.animationTriggered = animationTriggered
        self.activeCondition = activeCondition
    }
}

// MARK: - Session Metadata Log

struct SessionMetadataLog: Codable {
    let sessionID: String
    let participantID: String
    let dateTime: Date
    let conditionOrder: ConditionOrder
    let targetRotation: TargetRotation
    let blockConfigurations: [BlockMetadata]
    let deviceInfo: String
    let appVersion: String

    struct BlockMetadata: Codable {
        let blockNumber: Int
        let condition: VisualCondition
        let target1: SoundCategory
        let target2: SoundCategory
        let articleID: String
    }
}

// MARK: - System Performance Log

struct SystemPerformanceLog: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let classificationLatencyMs: Double?
    let batteryLevel: Float?
    let errorMessage: String?

    init(
        classificationLatencyMs: Double? = nil,
        batteryLevel: Float? = nil,
        errorMessage: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.classificationLatencyMs = classificationLatencyMs
        self.batteryLevel = batteryLevel
        self.errorMessage = errorMessage
    }
}

// MARK: - Session Data Export

struct SessionDataExport: Codable {
    let metadata: SessionMetadataLog
    let detectionEvents: [DetectionEventLog]
    let responseEvents: [ResponseEventLog]
    let pulseEvents: [PulseEventLog]
    let systemPerformance: [SystemPerformanceLog]
    let exportDate: Date

    func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

// MARK: - Trust Event (debug/researcher view)

struct TrustEvent: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let category: SoundCategory?
    let confidence: Double
    let triggered: Bool
    let reason: String
}

// MARK: - User Feedback

struct UserFeedback: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let confidence: Double
    let verdict: Verdict

    enum Verdict: String, Codable {
        case correct = "Correct"
        case wrong = "Wrong"
    }
}
