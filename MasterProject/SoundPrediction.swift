// SoundPrediction.swift
// Core data models for the sound awareness experiment
// UPDATE: Replace contents of your existing SoundPrediction.swift with this

import Foundation

// MARK: - Sound Categories

/// The 6 sound categories used in the experiment.
/// Each has routine and urgent intensity variants.
enum SoundCategory: String, CaseIterable, Codable, Identifiable {
    case knocking = "Knocking"
    case dogBarking = "Dog Barking"
    case babyCrying = "Baby Crying"
    case coughing = "Coughing"
    case glassBreaking = "Glass Breaking"
    case alarm = "Alarm"

    var id: String { rawValue }
    var displayName: String { rawValue }

    /// Haptic intensity for this category (does NOT vary with routine/urgent)
    var hapticLevel: HapticLevel {
        switch self {
        case .alarm, .babyCrying, .glassBreaking: return .heavy
        case .knocking, .coughing: return .medium
        case .dogBarking: return .light
        }
    }

    /// Maps Apple classifier labels to our 6 categories
    static func from(classifierLabel: String) -> SoundCategory? {
        let s = classifierLabel.lowercased()

        if s.contains("knock") || s.contains("tap") || s.contains("thump")
            || s.contains("bang") || s.contains("impact") || s.contains("door") {
            return .knocking
        }
        if s.contains("dog") || s.contains("bark") || s.contains("growl")
            || s.contains("whimper") || s.contains("howl") {
            return .dogBarking
        }
        if s.contains("baby") || s.contains("cry") || s.contains("infant") {
            return .babyCrying
        }
        if s.contains("cough") || s.contains("throat_clearing")
            || s.contains("sneeze") || s.contains("gasp") {
            return .coughing
        }
        if s.contains("glass") || s.contains("shatter") || s.contains("smash")
            || s.contains("crash") || s.contains("break") || s.contains("crack")
            || s.contains("clatter") || s.contains("clang") {
            return .glassBreaking
        }
        if s.contains("siren") || s.contains("alarm") || s.contains("ambulance")
            || s.contains("police") || s.contains("fire") || s.contains("emergency") {
            return .alarm
        }

        return nil
    }
}

// MARK: - Intensity Level

enum IntensityLevel: String, Codable, CaseIterable {
    case routine = "Routine"
    case urgent = "Urgent"
    var displayName: String { rawValue }
}

// MARK: - Visual Condition

enum VisualCondition: String, CaseIterable, Codable, Identifiable {
    case textOnly = "Text-Only"
    case staticIcon = "Static Icon"
    case animation = "Animation"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var code: String {
        switch self {
        case .textOnly: return "A"
        case .staticIcon: return "B"
        case .animation: return "C"
        }
    }
}

// MARK: - Haptic Level

enum HapticLevel: String, Codable {
    case light, medium, heavy
}

// MARK: - Confidence Bucket

enum ConfidenceBucket: String, Codable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    static func from(confidence: Double) -> ConfidenceBucket {
        if confidence >= 0.85 { return .high }
        if confidence >= 0.70 { return .medium }
        return .low
    }
}

// MARK: - Sound Prediction

struct SoundPrediction: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let confidence: Double
    let date: Date
    let category: SoundCategory?

    init(label: String, confidence: Double, date: Date = Date()) {
        self.label = label
        self.confidence = confidence
        self.date = date
        self.category = SoundCategory.from(classifierLabel: label)
    }

    var confidenceBucket: ConfidenceBucket {
        ConfidenceBucket.from(confidence: confidence)
    }
}

// MARK: - Awareness Display State

struct AwarenessDisplayState: Equatable {
    let category: SoundCategory
    let confidence: Double
    let intensityLevel: IntensityLevel
    let timestamp: Date

    var confidenceBucket: ConfidenceBucket {
        ConfidenceBucket.from(confidence: confidence)
    }
}
