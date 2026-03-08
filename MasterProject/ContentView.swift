// ContentView.swift

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sessionManager: ExperimentSessionManager
    @EnvironmentObject var classifier: SoundClassifierService

    var body: some View {
        Group {
            switch sessionManager.sessionState {
            case .idle:
                HomeHubView()
                    .environmentObject(sessionManager)
                    .environmentObject(classifier)

            case .trainingExp1:
                TrainingView(isSheet: false)
                    .environmentObject(sessionManager)

            case .trainingExp2:
                TrainingExp2View()
                    .environmentObject(sessionManager)
                    .environmentObject(classifier)

            case .exp1BlockReady, .exp1BlockActive, .exp1BlockComplete, .exp1Complete:
                Experiment1SessionView()
                    .environmentObject(sessionManager)

            case .exp2PracticeReady, .exp2PracticeActive,
                 .exp2BlockReady, .exp2BlockActive, .exp2BlockComplete,
                 .sessionComplete:
                Experiment2SessionView()
                    .environmentObject(sessionManager)
                    .environmentObject(classifier)

            default:
                HomeHubView()
                    .environmentObject(sessionManager)
                    .environmentObject(classifier)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: sessionManager.sessionState == .idle)
    }
}

// MARK: - Home Hub View

struct HomeHubView: View {
    @EnvironmentObject var sessionManager: ExperimentSessionManager
    @EnvironmentObject var classifier: SoundClassifierService

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 6) {
                        Image(systemName: "ear.and.waveform")
                            .font(.system(size: 48))
                            .foregroundStyle(.blue)
                        Text("Sound Awareness Study")
                            .font(.title2).bold()
                    }
                    .padding(.top, 20)

                    // Three main options
                    VStack(spacing: 14) {
                        trainingExp1Card
                        trainingExp2Card
                    }
                    .padding(.horizontal)

                    // Participant list
                    participantSection
                        .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Training Experiment 1 Card

    private var trainingExp1Card: some View {
        Button {
            sessionManager.sessionState = .trainingExp1
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Image(systemName: "eye.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Training — Experiment 1")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Preview text, icon, and animation formats")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Training Experiment 2 Card

    private var trainingExp2Card: some View {
        Button {
            sessionManager.sessionState = .trainingExp2
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 22))
                        .foregroundStyle(.purple)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Training — Experiment 2")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Live sound detection with modality options")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Participant List

    private var participantSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundStyle(.green)
                Text("Run Participant Session")
                    .font(.headline)
            }
            .padding(.top, 6)

            Text("Select a participant to start their full session. Counterbalancing is automatic.")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(CounterbalancingTable.all) { assignment in
                    participantButton(assignment)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    private func participantButton(_ assignment: CounterbalancingAssignment) -> some View {
        Button {
            sessionManager.configureAndStart(assignment: assignment)
        } label: {
            VStack(spacing: 4) {
                Text("\(assignment.participantNumber)")
                    .font(.title3).bold()
                Text("P\(String(format: "%02d", assignment.participantNumber))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Experiment 1 Session View (wraps grid + between-block controls)

struct Experiment1SessionView: View {
    @EnvironmentObject var sessionManager: ExperimentSessionManager

    var body: some View {
        ZStack {
            switch sessionManager.sessionState {
            case .exp1BlockReady(let n):
                blockReadyOverlay(block: n)

            case .exp1BlockActive:
                Experiment1GridView()
                    .environmentObject(sessionManager)

            case .exp1BlockComplete(let n):
                blockCompleteOverlay(block: n)

            case .exp1Complete:
                exp1CompleteOverlay

            default:
                EmptyView()
            }
        }
    }

    private func blockReadyOverlay(block: Int) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "\(block).circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            Text("Experiment 1 — Block \(block)")
                .font(.title2).bold()
            if let config = sessionManager.currentBlock {
                Text("Visual condition: \(config.visualCondition.displayName)")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Text("12 trials · 1s display · 5s response window")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button {
                sessionManager.startExp1Block()
            } label: {
                Label("Start Block \(block)", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.horizontal)
        }
        .padding()
    }

    private func blockCompleteOverlay(block: Int) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Block \(block) Complete")
                .font(.title2).bold()
            if let acc = sessionManager.exp1BlockAccuracy {
                Text("Accuracy: \(String(format: "%.0f%%", acc * 100))")
                    .font(.headline).foregroundStyle(.green)
            }
            Text("Administer the post-block questionnaire now.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                sessionManager.proceedAfterExp1Block()
            } label: {
                Label(block < 3 ? "Next Block" : "Continue to Experiment 2",
                      systemImage: block < 3 ? "arrow.right" : "arrow.right.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(block < 3 ? .blue : .green)
            .padding(.horizontal)

            Button("Back to Home", role: .destructive) {
                sessionManager.resetSession()
            }
            .font(.caption)
            .padding(.bottom, 8)
        }
        .padding()
    }

    private var exp1CompleteOverlay: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "flag.checkered")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            Text("Experiment 1 Complete")
                .font(.title2).bold()
            Text("Administer the comparative questionnaire.\nWhen ready, continue to Experiment 2.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                sessionManager.prepareExp2Practice()
            } label: {
                Label("Continue to Experiment 2", systemImage: "arrow.right.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal)

            Button("Back to Home", role: .destructive) {
                sessionManager.resetSession()
            }
            .font(.caption)
            .padding(.bottom, 8)
        }
        .padding()
    }
}

// MARK: - Experiment 2 Session View

struct Experiment2SessionView: View {
    @EnvironmentObject var sessionManager: ExperimentSessionManager
    @EnvironmentObject var classifier: SoundClassifierService

    var body: some View {
        ZStack {
            switch sessionManager.sessionState {
            case .exp2PracticeReady:
                practiceReadyOverlay

            case .exp2PracticeActive:
                Experiment2LiveView()
                    .environmentObject(sessionManager)
                    .environmentObject(classifier)

            case .exp2BlockReady(let n):
                blockReadyOverlay(block: n)

            case .exp2BlockActive:
                Experiment2LiveView()
                    .environmentObject(sessionManager)
                    .environmentObject(classifier)

            case .exp2BlockComplete(let n):
                blockCompleteOverlay(block: n)

            case .sessionComplete:
                sessionCompleteOverlay

            default:
                EmptyView()
            }
        }
    }

    private var practiceReadyOverlay: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "figure.walk")
                .font(.system(size: 64))
                .foregroundStyle(.purple)
            Text("Experiment 2 — Practice Block")
                .font(.title2).bold()
            Text("The participant puts on headphones and reads a short passage while the system monitors sounds. No scoring.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            Button {
                classifier.hapticsEnabled = true  // Practice uses haptic
                classifier.audioFeedbackEnabled = false
                if !classifier.isListening { classifier.start() }
                sessionManager.startExp2Practice()
            } label: {
                Label("Start Practice", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .padding(.horizontal)
        }
        .padding()
    }

    private func blockReadyOverlay(block: Int) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "\(block).circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Experiment 2 — Block \(block)")
                .font(.title2).bold()
            if let config = sessionManager.currentBlock {
                Text("Modality: \(config.feedbackModality.displayName)")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Targets: \(config.targetCategory1.displayName), \(config.targetCategory2.displayName) (urgent only)")
                    .font(.caption).foregroundStyle(.orange)
            }
            Spacer()
            Button {
                // Set classifier feedback flags based on this block's modality
                if let config = sessionManager.currentBlock {
                    classifier.hapticsEnabled = config.feedbackModality.hapticsEnabled
                    classifier.audioFeedbackEnabled = config.feedbackModality.audioEnabled
                }
                if !classifier.isListening { classifier.start() }
                sessionManager.startExp2Block()
            } label: {
                Label("Start Block \(block)", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal)
        }
        .padding()
    }

    private func blockCompleteOverlay(block: Int) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Block \(block) Complete")
                .font(.title2).bold()
            if let stats = sessionManager.currentBlockStats {
                HStack(spacing: 16) {
                    StatPill(label: "Hits", value: "\(stats.hits)", color: .green)
                    StatPill(label: "I-FA", value: "\(stats.intensityFalseAlarms)", color: .orange)
                    StatPill(label: "C-FA", value: "\(stats.categoryFalseAlarms)", color: .red)
                    StatPill(label: "Miss", value: "\(stats.misses)", color: .gray)
                }
                if let rt = stats.meanReactionTimeMs {
                    Text("Mean RT: \(Int(rt)) ms")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("Administer the post-block questionnaire now.")
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Button {
                classifier.stop()
                classifier.hapticsEnabled = false
                classifier.audioFeedbackEnabled = false
                sessionManager.proceedAfterExp2Block()
            } label: {
                Label(block < 3 ? "Next Block" : "Finish Session",
                      systemImage: block < 3 ? "arrow.right" : "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(block < 3 ? .green : .blue)
            .padding(.horizontal)
        }
        .padding()
    }

    private var sessionCompleteOverlay: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "party.popper.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            Text("Session Complete!")
                .font(.title).bold()
            Text("Conduct the final interview, then export data.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                exportData()
            } label: {
                Label("Export Session Data", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Button("Back to Home") {
                classifier.stop()
                sessionManager.resetSession()
            }
            .font(.subheadline)
            .padding(.bottom, 8)
        }
        .padding()
    }

    private func exportData() {
        guard let data = sessionManager.exportSessionData() else { return }
        do {
            let url = try DataExportService.shared.saveToDocuments(data)
            DataExportService.shared.shareFiles([url])
        } catch {
            print("Export failed:", error)
        }
    }
}

// MARK: - Experiment 2 Live View (the actual monitoring view)

struct Experiment2LiveView: View {
    @EnvironmentObject var sessionManager: ExperimentSessionManager
    @EnvironmentObject var classifier: SoundClassifierService

    var body: some View {
        VStack(spacing: 16) {
            header
            statusRow

            if sessionManager.isExp2BlockActive {
                experimentInfoBar
            }

            notificationArea
            Spacer(minLength: 0)

            if sessionManager.isExp2BlockActive || sessionManager.sessionState == .exp2PracticeActive {
                confirmButton
            }

            bottomControls
        }
        .padding()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(sessionManager.sessionState == .exp2PracticeActive
                     ? "Practice Block" : "Experiment 2")
                    .font(.title2).bold()
                if let block = sessionManager.currentBlock {
                    let modLabel = sessionManager.activeModality.displayName
                    Text(sessionManager.sessionState == .exp2PracticeActive
                         ? "Acclimatisation — \(modLabel)"
                         : "Block \(block.blockNumber) — \(modLabel)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if sessionManager.isExp2BlockActive || sessionManager.sessionState == .exp2PracticeActive {
                Text(formatTime(sessionManager.elapsedSeconds))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusRow: some View {
        HStack(spacing: 10) {
            Circle()
                .frame(width: 10, height: 10)
                .foregroundStyle(classifier.isListening ? .green : .secondary)
            Text(classifier.isListening ? "Listening" : "Not listening")
                .foregroundStyle(classifier.isListening ? .primary : .secondary)
            Spacer()
            // Modality badge
            Label(sessionManager.activeModality.displayName, systemImage: modalityIcon)
                .font(.caption).bold()
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(modalityColor.opacity(0.15))
                .clipShape(Capsule())
        }
    }

    private var modalityIcon: String {
        switch sessionManager.activeModality {
        case .visualOnly:   return "eye"
        case .visualHaptic: return "iphone.radiowaves.left.and.right"
        case .visualAudio:  return "speaker.wave.2"
        }
    }

    private var modalityColor: Color {
        switch sessionManager.activeModality {
        case .visualOnly:   return .blue
        case .visualHaptic: return .purple
        case .visualAudio:  return .green
        }
    }

    @ViewBuilder
    private var experimentInfoBar: some View {
        if let block = sessionManager.currentBlock {
            VStack(spacing: 6) {
                HStack {
                    Text("Targets: \(block.targetCategory1.displayName), \(block.targetCategory2.displayName)")
                        .font(.caption2).bold()
                    Text("(urgent only)").font(.caption2).foregroundStyle(.orange)
                    Spacer()
                }
            }
            .padding(10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var notificationArea: some View {
        if let display = classifier.currentDisplay {
            AnimationNotificationCard(display: display, classifier: classifier)
        } else {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.secondary.opacity(0.05))
                .frame(height: 200)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary.opacity(0.4))
                        Text("Monitoring...")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                )
        }
    }

    private var confirmButton: some View {
        Button {
            classifier.handleConfirmTap()
        } label: {
            HStack {
                Image(systemName: "hand.tap.fill")
                Text("Confirm — Urgent Target Sound")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
    }

    private var bottomControls: some View {
        HStack {
            if sessionManager.sessionState == .exp2PracticeActive {
                Button {
                    classifier.stop()
                    classifier.hapticsEnabled = false
                    classifier.audioFeedbackEnabled = false
                    sessionManager.endExp2Practice()
                } label: {
                    Label("End Practice", systemImage: "stop.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else if sessionManager.isExp2BlockActive {
                Button {
                    classifier.stop()
                    classifier.hapticsEnabled = false
                    classifier.audioFeedbackEnabled = false
                    sessionManager.endExp2Block()
                } label: {
                    Label("End Block", systemImage: "stop.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            Spacer()

            if !classifier.isListening && (sessionManager.isExp2BlockActive || sessionManager.sessionState == .exp2PracticeActive) {
                Button {
                    classifier.start()
                } label: {
                    Label("Start Listening", systemImage: "mic.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Animation Notification Card (Experiment 2)

struct AnimationNotificationCard: View {
    let display: AwarenessDisplayState
    @ObservedObject var classifier: SoundClassifierService

    var body: some View {
        VStack(spacing: 8) {
            animationView
                .frame(height: 160)
            HStack {
                Text(display.category.displayName)
                    .font(.subheadline).bold()
                Spacer()
                Text(display.confidenceBucket.rawValue)
                    .font(.caption2).bold()
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(confidenceColor.opacity(0.2))
                    .clipShape(Capsule())
                    .foregroundStyle(confidenceColor)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(display.intensityLevel == .urgent
                      ? Color.orange.opacity(0.08)
                      : Color.blue.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(display.intensityLevel == .urgent
                        ? Color.orange.opacity(0.4)
                        : Color.blue.opacity(0.3), lineWidth: 2)
        )
    }

    @ViewBuilder
    private var animationView: some View {
        let pulseID = classifier.pulseIDs[display.category] ?? 0
        switch display.category {
        case .knocking:      KnockAnimationView(pulseID: pulseID, intensity: display.intensityLevel)
        case .dogBarking:    DogBarkAnimationView(pulseID: pulseID, intensity: display.intensityLevel)
        case .babyCrying:    BabyCryAnimationView(pulseID: pulseID, intensity: display.intensityLevel)
        case .alarm:         AlarmAnimationView(pulseID: pulseID, intensity: display.intensityLevel)
        case .coughing:      CoughAnimationView(pulseID: pulseID, intensity: display.intensityLevel)
        case .glassBreaking: GlassBreakAnimationView(pulseID: pulseID, intensity: display.intensityLevel)
        }
    }

    private var confidenceColor: Color {
        switch display.confidenceBucket {
        case .high:   return .green
        case .medium: return .orange
        case .low:    return .red
        }
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).bold().foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Training Experiment 2 View

struct TrainingExp2View: View {
    @EnvironmentObject var sessionManager: ExperimentSessionManager
    @EnvironmentObject var classifier: SoundClassifierService

    @State private var selectedModality: FeedbackModality = .visualOnly

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Training — Experiment 2")
                        .font(.title2).bold()
                    Text("Live sound detection. Switch modalities to demonstrate each feedback type.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Back") {
                    classifier.stop()
                    sessionManager.sessionState = .idle
                }
                .font(.subheadline)
            }

            // Modality picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Feedback modality:")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Modality", selection: $selectedModality) {
                    ForEach(FeedbackModality.allCases) { modality in
                        Text(modality.displayName).tag(modality)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedModality) { oldValue, newValue in
                    print("🔄 Modality changed to: \(newValue.displayName) | haptics=\(newValue.hapticsEnabled) | audio=\(newValue.audioEnabled)")
                    classifier.hapticsEnabled = newValue.hapticsEnabled
                    classifier.audioFeedbackEnabled = newValue.audioEnabled
                    sessionManager.activeModality = newValue
                }
            }
            .padding(12)
            .background(Color.purple.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Status
            HStack(spacing: 10) {
                Circle()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(classifier.isListening ? .green : .secondary)
                Text(classifier.isListening ? "Listening" : "Not listening")
                Spacer()
            }

            // Notification area
            if let display = classifier.currentDisplay {
                AnimationNotificationCard(display: display, classifier: classifier)
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.secondary.opacity(0.05))
                    .frame(height: 200)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "waveform")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary.opacity(0.4))
                            Text(classifier.isListening ? "Monitoring..." : "Tap Start to begin")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    )
            }

            Spacer()

            // Start/Stop listening
            Button {
                if classifier.isListening {
                    classifier.stop()
                } else {
                    classifier.hapticsEnabled = selectedModality.hapticsEnabled
                    classifier.audioFeedbackEnabled = selectedModality.audioEnabled
                    classifier.start()
                }
            } label: {
                Label(classifier.isListening ? "Stop Listening" : "Start Listening",
                      systemImage: classifier.isListening ? "stop.fill" : "mic.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(classifier.isListening ? .red : .green)
        }
        .padding()
        .onDisappear {
            classifier.stop()
            classifier.hapticsEnabled = false
            classifier.audioFeedbackEnabled = false
        }
    }
}
