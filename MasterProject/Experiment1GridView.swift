// Experiment1GridView.swift

import SwiftUI

struct Experiment1GridView: View {
    @EnvironmentObject var sessionManager: ExperimentSessionManager

    private let columns = [GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 14) {
            headerBar
            trialStatusBar
            soundGrid
            Spacer(minLength: 0)
            responseArea
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(sessionManager.exp1IsPractice ? "Practice" : "Experiment 1")
                    .font(.title2).bold()
                if let block = sessionManager.currentBlock {
                    Text("Block \(block.blockNumber) of 3  ·  \(block.visualCondition.displayName)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            let total = sessionManager.experiment1Trials.count
            let done  = sessionManager.experiment1TrialIndex
            if total > 0 {
                VStack(spacing: 2) {
                    Text("\(done)/\(total)")
                        .font(.headline.monospacedDigit()).bold()
                    Text("trials done")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.trailing, 52)
    }

    // MARK: - Trial Status Bar

    @ViewBuilder
    private var trialStatusBar: some View {
        switch sessionManager.exp1TrialPhase {
        case .displaying:
            HStack(spacing: 10) {
                Image(systemName: "eye.fill").foregroundStyle(.blue)
                Text("Observe the notification")
                    .font(.subheadline).bold()
                Spacer()
                Text("1s display")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

        case .respondingCategory:
            HStack(spacing: 10) {
                Image(systemName: "hand.tap.fill").foregroundStyle(.orange)
                Text("Select the sound category")
                    .font(.subheadline).bold()
                Spacer()
                Text(String(format: "%.1fs", sessionManager.exp1ResponseTimeRemaining))
                    .font(.caption.monospacedDigit()).foregroundStyle(.orange)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

        case .respondingIntensity:
            HStack(spacing: 10) {
                Image(systemName: "hand.tap.fill").foregroundStyle(.purple)
                Text("Select the intensity")
                    .font(.subheadline).bold()
                Spacer()
                Text(String(format: "%.1fs", sessionManager.exp1ResponseTimeRemaining))
                    .font(.caption.monospacedDigit()).foregroundStyle(.purple)
            }
            .padding(12)
            .background(Color.purple.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

        case .pausing:
            HStack(spacing: 10) {
                Image(systemName: "pause.circle").foregroundStyle(.secondary)
                Text("Next trial coming...")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
            .background(Color.secondary.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))

        case .idle:
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle").foregroundStyle(.green)
                Text(sessionManager.experiment1TrialIndex == 0
                     ? "Block ready — trials will begin automatically"
                     : "Block complete")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
            .background(Color.secondary.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Sound Grid

    private var soundGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(SoundCategory.allCases) { category in
                SoundCellView(
                    category: category,
                    activeTrial: sessionManager.exp1TrialPhase == .displaying
                        ? sessionManager.currentExperiment1Trial : nil,
                    condition: sessionManager.currentBlock?.visualCondition ?? .animation,
                    pulseID: sessionManager.exp1PulseIDs[category] ?? 0
                )
            }
        }
    }

    // MARK: - Response Area (sequential: category first, then intensity)

    @ViewBuilder
    private var responseArea: some View {
        switch sessionManager.exp1TrialPhase {
        case .respondingCategory:
            categorySelectionView
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: sessionManager.exp1TrialPhase)

        case .respondingIntensity:
            VStack(spacing: 14) {
                // Show selected category as confirmation
                if let selected = sessionManager.exp1SelectedCategory {
                    HStack {
                        Text("Selected: \(selected.displayName)")
                            .font(.caption).bold().foregroundStyle(.blue)
                        Spacer()
                    }
                }
                intensitySelectionView
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: sessionManager.exp1TrialPhase)

        default:
            EmptyView()
        }
    }

    private var categorySelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Which sound was shown?")
                .font(.subheadline).bold()
            LazyVGrid(columns: [GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())], spacing: 8) {
                ForEach(SoundCategory.allCases) { cat in
                    categoryButton(cat)
                }
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var intensitySelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How intense did it appear?")
                .font(.subheadline).bold()
            HStack(spacing: 10) {
                intensityButton(.routine,
                                label: "Gentle / Routine",
                                icon: "tortoise.fill",
                                color: .blue)
                intensityButton(.urgent,
                                label: "Forceful / Urgent",
                                icon: "hare.fill",
                                color: .orange)
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func categoryButton(_ category: SoundCategory) -> some View {
        Button {
            sessionManager.selectCategory(category)
        } label: {
            Text(category.displayName)
                .font(.caption).bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func intensityButton(_ intensity: IntensityLevel,
                                  label: String, icon: String, color: Color) -> some View {
        Button {
            sessionManager.selectIntensity(intensity)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.caption).bold()
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
    }
}

// MARK: - Individual Sound Cell

private struct SoundCellView: View {
    let category: SoundCategory
    let activeTrial: Experiment1Trial?
    let condition: VisualCondition
    let pulseID: Int

    private var isActive: Bool { activeTrial?.shownCategory == category }
    private var intensity: IntensityLevel { activeTrial?.shownIntensity ?? .routine }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(isActive
                      ? Color.secondary.opacity(0.12)
                      : Color.secondary.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isActive
                                ? Color.secondary.opacity(0.5)
                                : Color.clear,
                                lineWidth: 2.5)
                )

            if isActive {
                activeContent
            } else {
                // Blank neutral cell — no labels, no icons
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.clear)
            }
        }
        .frame(height: 155)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    // Active state — show the condition's visual representation
    @ViewBuilder
    private var activeContent: some View {
        switch condition {
        case .textOnly:   textOnlyContent
        case .staticIcon: staticIconContent
        case .animation:  animationContent
        }
    }

    private var textOnlyContent: some View {
        VStack(spacing: 8) {
            Text(category.displayName)
                .font(.headline).bold()
            Text(intensity.displayName.uppercased())
                .font(.caption).bold()
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.secondary.opacity(0.15))
                .clipShape(Capsule())
                .foregroundStyle(.primary)
        }
        .padding(8)
    }

    private var staticIconContent: some View {
        VStack(spacing: 6) {
            StaticSoundIcon(category: category, intensity: intensity)
                .frame(height: 100)
        }
        .padding(6)
    }

    @ViewBuilder
    private var animationContent: some View {
        Group {
            switch category {
            case .knocking:      KnockAnimationView(pulseID: pulseID, intensity: intensity)
            case .dogBarking:    DogBarkAnimationView(pulseID: pulseID, intensity: intensity)
            case .babyCrying:    BabyCryAnimationView(pulseID: pulseID, intensity: intensity)
            case .alarm:         AlarmAnimationView(pulseID: pulseID, intensity: intensity)
            case .coughing:      CoughAnimationView(pulseID: pulseID, intensity: intensity)
            case .glassBreaking: GlassBreakAnimationView(pulseID: pulseID, intensity: intensity)
            }
        }
        .padding(4)
    }
}
