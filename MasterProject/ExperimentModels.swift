// ExperimentModels.swift

import Foundation

// MARK: - Experiment Phase

enum ExperimentPhase: String, Codable, CaseIterable {
    case experiment1 = "Experiment 1"
    case experiment2 = "Experiment 2"
}

// MARK: - Feedback Modality (Experiment 2 only)

enum FeedbackModality: String, CaseIterable, Codable, Identifiable {
    case visualOnly    = "Visual Only"
    case visualHaptic  = "Visual + Haptic"
    case visualAudio   = "Visual + Audio"

    var id: String { rawValue }
    var displayName: String { rawValue }
    var code: String {
        switch self {
        case .visualOnly:   return "D"
        case .visualHaptic: return "E"
        case .visualAudio:  return "F"
        }
    }
    var hapticsEnabled: Bool { self == .visualHaptic }
    var audioEnabled: Bool   { self == .visualAudio  }
}

// MARK: - Target Pair Rotation

enum TargetRotation: String, CaseIterable, Codable {
    case rotationA = "A"
    case rotationB = "B"
    case rotationC = "C"

    func targets(forBlock block: Int) -> (SoundCategory, SoundCategory) {
        let pairs: [(SoundCategory, SoundCategory)] = [
            (.knocking, .dogBarking),
            (.babyCrying, .coughing),
            (.glassBreaking, .alarm)
        ]
        let index: Int
        switch self {
        case .rotationA: index = (block - 1) % 3
        case .rotationB: index = block % 3
        case .rotationC: index = (block + 1) % 3
        }
        return pairs[index]
    }
}

// MARK: - Condition Order (Experiment 1)

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

    static let allOrders: [ConditionOrder] = [
        ConditionOrder(block1: .textOnly,   block2: .staticIcon, block3: .animation),
        ConditionOrder(block1: .textOnly,   block2: .animation,  block3: .staticIcon),
        ConditionOrder(block1: .staticIcon, block2: .textOnly,   block3: .animation),
        ConditionOrder(block1: .staticIcon, block2: .animation,  block3: .textOnly),
        ConditionOrder(block1: .animation,  block2: .textOnly,   block3: .staticIcon),
        ConditionOrder(block1: .animation,  block2: .staticIcon, block3: .textOnly),
    ]
}

// MARK: - Modality Order (Experiment 2)

struct ModalityOrder: Codable, Equatable {
    let block1: FeedbackModality
    let block2: FeedbackModality
    let block3: FeedbackModality

    func modality(forBlock block: Int) -> FeedbackModality {
        switch block {
        case 1: return block1
        case 2: return block2
        case 3: return block3
        default: return block1
        }
    }

    static let allOrders: [ModalityOrder] = [
        ModalityOrder(block1: .visualOnly,   block2: .visualHaptic, block3: .visualAudio),
        ModalityOrder(block1: .visualOnly,   block2: .visualAudio,  block3: .visualHaptic),
        ModalityOrder(block1: .visualHaptic, block2: .visualOnly,   block3: .visualAudio),
        ModalityOrder(block1: .visualHaptic, block2: .visualAudio,  block3: .visualOnly),
        ModalityOrder(block1: .visualAudio,  block2: .visualOnly,   block3: .visualHaptic),
        ModalityOrder(block1: .visualAudio,  block2: .visualHaptic, block3: .visualOnly),
    ]
}

// MARK: - Session Configuration

struct SessionConfiguration: Codable, Identifiable {
    let id: String
    let participantID: String
    let conditionOrder: ConditionOrder
    let modalityOrder: ModalityOrder
    let targetRotation: TargetRotation
    let articleAssignment: [String]              // 3 articles for Exp 2
}

// MARK: - Block Configuration

struct BlockConfiguration: Identifiable {
    let id = UUID()
    let blockNumber: Int
    let experimentPhase: ExperimentPhase
    var visualCondition: VisualCondition = .animation
    var feedbackModality: FeedbackModality = .visualOnly
    var targetCategory1: SoundCategory = .knocking
    var targetCategory2: SoundCategory = .dogBarking
    var articleID: String = "article1"

    func isTarget(_ category: SoundCategory) -> Bool {
        category == targetCategory1 || category == targetCategory2
    }
}

// MARK: - Experiment 1 Trial

struct Experiment1Trial: Identifiable, Codable {
    let id: UUID
    let trialNumber: Int
    let blockNumber: Int
    let visualCondition: VisualCondition
    let shownCategory: SoundCategory
    let shownIntensity: IntensityLevel

    init(trialNumber: Int, blockNumber: Int, visualCondition: VisualCondition,
         shownCategory: SoundCategory, shownIntensity: IntensityLevel) {
        self.id = UUID()
        self.trialNumber = trialNumber
        self.blockNumber = blockNumber
        self.visualCondition = visualCondition
        self.shownCategory = shownCategory
        self.shownIntensity = shownIntensity
    }

    /// 12 trials per block: each of 6 categories shown at routine then urgent intensity, shuffled.
    static func trials(forBlock blockNumber: Int, condition: VisualCondition) -> [Experiment1Trial] {
        var result: [Experiment1Trial] = []
        for category in SoundCategory.allCases {
            result.append(Experiment1Trial(trialNumber: 0, blockNumber: blockNumber,
                                           visualCondition: condition, shownCategory: category, shownIntensity: .routine))
            result.append(Experiment1Trial(trialNumber: 0, blockNumber: blockNumber,
                                           visualCondition: condition, shownCategory: category, shownIntensity: .urgent))
        }
        result.shuffle()
        // Assign sequential trial numbers after shuffling
        for i in result.indices {
            result[i] = Experiment1Trial(trialNumber: i + 1, blockNumber: blockNumber,
                                          visualCondition: condition, shownCategory: result[i].shownCategory,
                                          shownIntensity: result[i].shownIntensity)
        }
        return result
    }
}

// MARK: - Experiment 1 Response Log

struct Experiment1ResponseLog: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let trialID: UUID
    let trialNumber: Int
    let blockNumber: Int
    let visualCondition: VisualCondition
    let shownCategory: SoundCategory
    let shownIntensity: IntensityLevel
    let respondedCategory: SoundCategory?
    let respondedIntensity: IntensityLevel?
    let categoryReactionTimeMs: Double?   // time from display disappearance to category tap
    let intensityReactionTimeMs: Double?  // time from category tap to intensity tap
    let totalReactionTimeMs: Double       // time from display disappearance to final tap (or timeout)
    let categoryCorrect: Bool
    let intensityCorrect: Bool
    let fullyCorrect: Bool
    let timedOut: Bool

    init(trial: Experiment1Trial, respondedCategory: SoundCategory?,
         respondedIntensity: IntensityLevel?,
         categoryReactionTimeMs: Double?, intensityReactionTimeMs: Double?,
         totalReactionTimeMs: Double, timedOut: Bool) {
        self.id = UUID()
        self.timestamp = Date()
        self.trialID = trial.id
        self.trialNumber = trial.trialNumber
        self.blockNumber = trial.blockNumber
        self.visualCondition = trial.visualCondition
        self.shownCategory = trial.shownCategory
        self.shownIntensity = trial.shownIntensity
        self.respondedCategory = respondedCategory
        self.respondedIntensity = respondedIntensity
        self.categoryReactionTimeMs = categoryReactionTimeMs
        self.intensityReactionTimeMs = intensityReactionTimeMs
        self.totalReactionTimeMs = totalReactionTimeMs
        self.categoryCorrect  = respondedCategory == trial.shownCategory
        self.intensityCorrect = respondedIntensity == trial.shownIntensity
        self.fullyCorrect     = categoryCorrect && intensityCorrect && !timedOut
        self.timedOut = timedOut
    }
}

// MARK: - Response Classification (Experiment 2)

enum ResponseClassification: String, Codable {
    case hit                 = "HIT"
    case intensityFalseAlarm = "INTENSITY_FA"
    case categoryFalseAlarm  = "CATEGORY_FA"
    case miss                = "MISS"
    case correctRejection    = "CORRECT_REJECTION"

    static func classify(didTap: Bool, category: SoundCategory,
                         intensity: IntensityLevel, block: BlockConfiguration) -> ResponseClassification {
        let isTarget = block.isTarget(category)
        if didTap {
            if isTarget && intensity == .urgent  { return .hit }
            if isTarget && intensity == .routine { return .intensityFalseAlarm }
            return .categoryFalseAlarm
        } else {
            if isTarget && intensity == .urgent  { return .miss }
            return .correctRejection
        }
    }
}

// MARK: - Ground Truth Event (Experiment 2)

struct GroundTruthEvent: Codable, Identifiable {
    let id: UUID
    let timestampSeconds: Double
    let category: SoundCategory
    let intensity: IntensityLevel
    let durationSeconds: Double

    init(timestampSeconds: Double, category: SoundCategory,
         intensity: IntensityLevel, durationSeconds: Double = 7.0) {
        self.id = UUID()
        self.timestampSeconds = timestampSeconds
        self.category = category
        self.intensity = intensity
        self.durationSeconds = durationSeconds
    }
}

// MARK: - Track Configuration (Experiment 2)

struct TrackConfiguration: Codable {
    let trackDurationSeconds: Double
    let events: [GroundTruthEvent]
    let toleranceSeconds: Double

    static let defaultTrack: TrackConfiguration = {
        let events: [GroundTruthEvent] = [
            GroundTruthEvent(timestampSeconds: 15,  category: .knocking,      intensity: .routine),
            GroundTruthEvent(timestampSeconds: 45,  category: .glassBreaking, intensity: .urgent),
            GroundTruthEvent(timestampSeconds: 75,  category: .babyCrying,    intensity: .routine, durationSeconds: 8),
            GroundTruthEvent(timestampSeconds: 105, category: .dogBarking,    intensity: .urgent,  durationSeconds: 6),
            GroundTruthEvent(timestampSeconds: 135, category: .alarm,         intensity: .routine, durationSeconds: 8),
            GroundTruthEvent(timestampSeconds: 165, category: .coughing,      intensity: .urgent,  durationSeconds: 6),
            GroundTruthEvent(timestampSeconds: 195, category: .knocking,      intensity: .urgent),
            GroundTruthEvent(timestampSeconds: 225, category: .babyCrying,    intensity: .urgent,  durationSeconds: 8),
            GroundTruthEvent(timestampSeconds: 255, category: .dogBarking,    intensity: .routine, durationSeconds: 6),
            GroundTruthEvent(timestampSeconds: 285, category: .glassBreaking, intensity: .routine),
            GroundTruthEvent(timestampSeconds: 315, category: .coughing,      intensity: .routine, durationSeconds: 6),
            GroundTruthEvent(timestampSeconds: 345, category: .alarm,         intensity: .urgent,  durationSeconds: 8),
        ]
        return TrackConfiguration(trackDurationSeconds: 360, events: events, toleranceSeconds: 3.0)
    }()

    func matchEvent(category: SoundCategory, nearTimestamp timestamp: Double) -> GroundTruthEvent? {
        events.first { $0.category == category && abs($0.timestampSeconds - timestamp) <= toleranceSeconds }
    }
}

// MARK: - Block Statistics (Experiment 2)

struct BlockStatistics {
    let blockNumber: Int
    let condition: VisualCondition
    let modality: FeedbackModality
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
}
