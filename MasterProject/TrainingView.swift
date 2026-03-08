// TrainingView.swift
// Shown during the training phase before Experiment 1 begins.
//
// Purpose 1: Participant learns which cell position = which sound category.
// Purpose 2: Researcher can demonstrate all three visual conditions so
//            participants understand what text / icon / animation looks like
//            before any measured trials begin.
//
// The researcher controls which condition is previewed via a segmented picker.
// A "Start Experiment 1" button appears once training is complete.

import SwiftUI

struct TrainingView: View {
    @EnvironmentObject var sessionManager: ExperimentSessionManager
    var isSheet: Bool = false

    @State private var previewCondition: VisualCondition = .textOnly
    @State private var activeCategory: SoundCategory? = nil
    @State private var activeIntensity: IntensityLevel = .routine
    @State private var pulseIDs: [SoundCategory: Int] = {
        Dictionary(uniqueKeysWithValues: SoundCategory.allCases.map { ($0, 0) })
    }()

    private let columns = [GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 16) {
            header
            conditionPicker
            instructionBar
            grid
            Spacer(minLength: 0)
            demoControls
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Training — Experiment 1")
                    .font(.title2).bold()
                Text("Explore each visual format and intensity level. Tap any cell to preview it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Back") {
                sessionManager.sessionState = .idle
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Condition Picker

    private var conditionPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preview visual format:")
                .font(.caption).foregroundStyle(.secondary)
            Picker("Visual Condition", selection: $previewCondition) {
                ForEach(VisualCondition.allCases) { condition in
                    Text(condition.displayName).tag(condition)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(Color.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Instruction Bar

    private var instructionBar: some View {
        HStack(spacing: 10) {
            Image(systemName: activeCategory == nil
                  ? "hand.tap" : "eye.fill")
                .foregroundStyle(activeCategory == nil ? Color.secondary : Color.blue)
            Text(activeCategory == nil
                 ? "Tap a cell to preview how it looks when activated"
                 : "This is what participants will see during the experiment")
                .font(.caption)
                .foregroundStyle(activeCategory == nil ? Color.secondary : Color.primary)
            Spacer()
            if activeCategory != nil {
                Button("Clear") { activeCategory = nil }
                    .font(.caption).foregroundStyle(.blue)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(SoundCategory.allCases) { category in
                TrainingCellView(
                    category: category,
                    activeCategory: activeCategory,
                    activeIntensity: activeIntensity,
                    condition: previewCondition,
                    pulseID: pulseIDs[category] ?? 0
                )
                .onTapGesture {
                    activateCell(category)
                }
            }
        }
    }

    // MARK: - Demo Controls (intensity toggle)

    @ViewBuilder
    private var demoControls: some View {
        if activeCategory != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("Toggle intensity to show participant the difference:")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    intensityButton(.routine, label: "Gentle / Routine",
                                    icon: "tortoise.fill", color: .blue)
                    intensityButton(.urgent, label: "Forceful / Urgent",
                                    icon: "hare.fill", color: .orange)
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: activeCategory)
        }
    }

    private func intensityButton(_ intensity: IntensityLevel,
                                  label: String, icon: String, color: Color) -> some View {
        let selected = activeIntensity == intensity
        return Button {
            activeIntensity = intensity
            if let cat = activeCategory {
                pulseIDs[cat, default: 0] += 1
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label).font(.caption).bold()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selected ? color.opacity(0.15) : Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? color : .primary)
    }

    // MARK: - Helpers

    private func activateCell(_ category: SoundCategory) {
        activeCategory = category
        pulseIDs[category, default: 0] += 1

        // Fire a few extra pulses for animation condition
        if previewCondition == .animation {
            for delay in [0.2, 0.45, 0.70] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    pulseIDs[category, default: 0] += 1
                }
            }
        }
    }
}

// MARK: - Training Cell View
// Shows category label + icon always (so participant can memorise layout).
// When tapped/activated, shows the selected visual condition representation.

private struct TrainingCellView: View {
    let category: SoundCategory
    let activeCategory: SoundCategory?
    let activeIntensity: IntensityLevel
    let condition: VisualCondition
    let pulseID: Int

    private var isActive: Bool { activeCategory == category }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(isActive
                      ? (activeIntensity == .urgent
                         ? Color.orange.opacity(0.12)
                         : Color.blue.opacity(0.10))
                      : Color.secondary.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isActive
                                ? (activeIntensity == .urgent
                                   ? Color.orange.opacity(0.6)
                                   : Color.blue.opacity(0.5))
                                : Color.secondary.opacity(0.15),
                                lineWidth: isActive ? 2.5 : 1)
                )

            if isActive {
                activeContent
            } else {
                // Always show label + icon in training so participants memorise layout
                neutralWithLabel
            }
        }
        .frame(height: 155)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    // Neutral: full label and icon visible
    private var neutralWithLabel: some View {
        VStack(spacing: 8) {
            Image(systemName: neutralIcon)
                .font(.system(size: 28))
                .foregroundStyle(.secondary.opacity(0.6))
            Text(category.displayName)
                .font(.caption).bold()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Tap to preview")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private var activeContent: some View {
        switch condition {
        case .textOnly:
            VStack(spacing: 8) {
                Text(category.displayName).font(.headline).bold()
                Text(activeIntensity.displayName.uppercased())
                    .font(.caption).bold()
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(activeIntensity == .urgent
                                ? Color.orange.opacity(0.25)
                                : Color.blue.opacity(0.18))
                    .clipShape(Capsule())
                    .foregroundStyle(activeIntensity == .urgent ? .orange : .blue)
            }
            .padding(8)

        case .staticIcon:
            VStack(spacing: 4) {
                StaticSoundIcon(category: category, intensity: activeIntensity)
                    .frame(height: 100)
            }
            .padding(4)

        case .animation:
            Group {
                switch category {
                case .knocking:      KnockAnimationView(pulseID: pulseID, intensity: activeIntensity)
                case .dogBarking:    DogBarkAnimationView(pulseID: pulseID, intensity: activeIntensity)
                case .babyCrying:    BabyCryAnimationView(pulseID: pulseID, intensity: activeIntensity)
                case .alarm:         AlarmAnimationView(pulseID: pulseID, intensity: activeIntensity)
                case .coughing:      CoughAnimationView(pulseID: pulseID, intensity: activeIntensity)
                case .glassBreaking: GlassBreakAnimationView(pulseID: pulseID, intensity: activeIntensity)
                }
            }
            .padding(4)
        }
    }

    private var neutralIcon: String {
        switch category {
        case .knocking:      return "hand.raised"
        case .dogBarking:    return "pawprint"
        case .babyCrying:    return "face.smiling"
        case .coughing:      return "lungs"
        case .glassBreaking: return "wineglass"
        case .alarm:         return "bell"
        }
    }
}
