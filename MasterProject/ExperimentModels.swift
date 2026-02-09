// ExperimentModels.swift
// CREATE NEW FILE: Right-click MasterProject folder → New File → Swift File → "ExperimentModels"

import Foundation

// MARK: - Target Pair Rotation

enum TargetRotation: String, CaseIterable, Codable {
    case rotationA = "A"
    case rotationB = "B"
    case rotationC = "C"

    /// Returns the two target categories for a given block number (1, 2, or 3)
    func targets(forBlock block: Int) -> (SoundCategory, SoundCategory) {
        let pairs: [(SoundCategory, SoundCategory)] = [
            (.knocking, .dogBarking),
            (.babyCrying, .coughing),
            (.glassBreaking, .alarm)
        ]
        let index: Int
        switch self {
        case .rotationA: index = block - 1
        case .rotationB: index = (block + 0) % 3
        case .rotationC: index = (block + 1) % 3
        }
        return pairs[index]
    }
}

// MARK: - Condition Order

struct ConditionOrder: Codable, Equatable {
    let block1: VisualCondition
    let block2: VisualCondition
    let block3: VisualCondition

    func condition(forBlock block: Int) -> VisualCondition {
        switch block {
        case 1: return block1
        case 2: return block2
        case 3: return block3
        default: return block1
        }
    }

    /// All 6 Latin Square permutations
    static let allOrders: [ConditionOrder] = [
        ConditionOrder(block1: .textOnly,   block2: .staticIcon, block3: .animation),
        ConditionOrder(block1: .textOnly,   block2: .animation,  block3: .staticIcon),
        ConditionOrder(block1: .staticIcon, block2: .textOnly,   block3: .animation),
        ConditionOrder(block1: .staticIcon, block2: .animation,  block3: .textOnly),
        ConditionOrder(block1: .animation,  block2: .textOnly,   block3: .staticIcon),
        ConditionOrder(block1: .animation,  block2: .staticIcon, block3: .textOnly),
    ]
}

// MARK: - Session Configuration

struct SessionConfiguration: Codable, Identifiable {
    let id: String
    let participantID: String
    let conditionOrder: ConditionOrder
    let targetRotation: TargetRotation
    let articleAssignment: [String]

    /// Generate all 18 counterbalancing combinations
    static func generateAllConfigurations() -> [SessionConfiguration] {
        var configs: [SessionConfiguration] = []
        var index = 1
        for order in ConditionOrder.allOrders {
            for rotation in TargetRotation.allCases {
                configs.append(SessionConfiguration(
                    id: String(format: "P%02d", index),
                    participantID: "",
                    conditionOrder: order,
                    targetRotation: rotation,
                    articleAssignment: ["article1", "article2", "article3"]
                ))
                index += 1
            }
        }
        return configs
    }
}

// MARK: - Block Configuration

struct BlockConfiguration: Identifiable {
    let id = UUID()
    let blockNumber: Int
    let visualCondition: VisualCondition
    let targetCategory1: SoundCategory
    let targetCategory2: SoundCategory
    let articleID: String

    func isTarget(_ category: SoundCategory) -> Bool {
        category == targetCategory1 || category == targetCategory2
    }
}

// MARK: - Response Classification

enum ResponseClassification: String, Codable {
    case hit = "HIT"
    case intensityFalseAlarm = "INTENSITY_FA"
    case categoryFalseAlarm = "CATEGORY_FA"
    case miss = "MISS"
    case correctRejection = "CORRECT_REJECTION"

    static func classify(
        didTap: Bool,
        category: SoundCategory,
        intensity: IntensityLevel,
        block: BlockConfiguration
    ) -> ResponseClassification {
        let isTarget = block.isTarget(category)
        if didTap {
            if isTarget && intensity == .urgent { return .hit }
            if isTarget && intensity == .routine { return .intensityFalseAlarm }
            return .categoryFalseAlarm
        } else {
            if isTarget && intensity == .urgent { return .miss }
            return .correctRejection
        }
    }
}

// MARK: - Ground Truth Event

struct GroundTruthEvent: Codable, Identifiable {
    let id: UUID
    let timestampSeconds: Double
    let category: SoundCategory
    let intensity: IntensityLevel
    let durationSeconds: Double

    init(timestampSeconds: Double, category: SoundCategory, intensity: IntensityLevel, durationSeconds: Double = 7.0) {
        self.id = UUID()
        self.timestampSeconds = timestampSeconds
        self.category = category
        self.intensity = intensity
        self.durationSeconds = durationSeconds
    }
}

// MARK: - Track Configuration

struct TrackConfiguration: Codable {
    let trackDurationSeconds: Double
    let events: [GroundTruthEvent]
    let toleranceSeconds: Double

    static let defaultTrack: TrackConfiguration = {
        let events: [GroundTruthEvent] = [
            GroundTruthEvent(timestampSeconds: 15,  category: .knocking,   intensity: .routine),
            GroundTruthEvent(timestampSeconds: 45,  category: .glassBreaking,  intensity: .urgent),
            GroundTruthEvent(timestampSeconds: 75,  category: .babyCrying, intensity: .routine, durationSeconds: 8),
            GroundTruthEvent(timestampSeconds: 105, category: .dogBarking, intensity: .urgent, durationSeconds: 6),
            GroundTruthEvent(timestampSeconds: 135, category: .alarm,      intensity: .routine, durationSeconds: 8),
            GroundTruthEvent(timestampSeconds: 165, category: .coughing,   intensity: .urgent, durationSeconds: 6),
            GroundTruthEvent(timestampSeconds: 195, category: .knocking,   intensity: .urgent),
            GroundTruthEvent(timestampSeconds: 225, category: .babyCrying, intensity: .urgent, durationSeconds: 8),
            GroundTruthEvent(timestampSeconds: 255, category: .dogBarking, intensity: .routine, durationSeconds: 6),
            GroundTruthEvent(timestampSeconds: 285, category: .glassBreaking,  intensity: .routine),
            GroundTruthEvent(timestampSeconds: 315, category: .coughing,   intensity: .routine, durationSeconds: 6),
            GroundTruthEvent(timestampSeconds: 345, category: .alarm,      intensity: .urgent, durationSeconds: 8),
        ]
        return TrackConfiguration(trackDurationSeconds: 360, events: events, toleranceSeconds: 3.0)
    }()

    func matchEvent(category: SoundCategory, nearTimestamp timestamp: Double) -> GroundTruthEvent? {
        events.first { $0.category == category && abs($0.timestampSeconds - timestamp) <= toleranceSeconds }
    }
}
