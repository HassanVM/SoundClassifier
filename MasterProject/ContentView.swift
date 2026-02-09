// ContentView.swift
// UPDATE: Replace your entire existing ContentView.swift with this

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sessionManager: ExperimentSessionManager
    @EnvironmentObject var classifier: SoundClassifierService

    @State private var showResearcherPanel = false
    @State private var showLogSheet = false

    var body: some View {
        ZStack {
            mainUI
        }
        .padding()
        .sheet(isPresented: $showResearcherPanel) {
            ResearcherPanelSheet()
                .environmentObject(sessionManager)
                .environmentObject(classifier)
        }
        .sheet(isPresented: $showLogSheet) {
            LogsSheet(trustEvents: classifier.recentTrustEvents, feedback: classifier.feedbackLog)
        }
    }

    // MARK: - Main UI

    private var mainUI: some View {
        VStack(spacing: 16) {
            header
            statusRow

            // Experiment info bar (when session active)
            if sessionManager.sessionState != .idle {
                experimentInfoBar
            }

            // Sound notification area — condition-aware
            notificationArea

            // Confirm button (participant taps when they see urgent target)
            if sessionManager.isBlockActive {
                confirmButton
            }

            controls
            debugCard
            Spacer(minLength: 0)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("MasterProject")
                    .font(.title2).bold()
                Text("On-device sound awareness")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Button { showLogSheet = true } label: {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 18, weight: .semibold))
            }

            Button { showResearcherPanel = true } label: {
                Image(systemName: "gearshape.2")
                    .font(.system(size: 18, weight: .semibold))
            }
        }
    }

    // MARK: - Status

    private var statusRow: some View {
        HStack(spacing: 10) {
            Circle()
                .frame(width: 10, height: 10)
                .foregroundStyle(classifier.isListening ? .green : .secondary)
            Text(classifier.isListening ? "Listening" : "Not listening")
                .foregroundStyle(classifier.isListening ? .primary : .secondary)
            Spacer()
            if let d = classifier.lastUpdate {
                Text("Updated \(d.formatted(date: .omitted, time: .standard))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Experiment Info Bar

    private var experimentInfoBar: some View {
        VStack(spacing: 6) {
            if let block = sessionManager.currentBlock {
                HStack {
                    Text("Block \(block.blockNumber)")
                        .font(.caption).bold()
                    Text("•")
                    Text(block.visualCondition.displayName)
                        .font(.caption)
                    Spacer()
                    if sessionManager.isBlockActive {
                        Text(formatTime(sessionManager.elapsedSeconds))
                            .font(.caption.monospacedDigit())
                    }
                }

                HStack {
                    Text("Targets:")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text("\(block.targetCategory1.displayName), \(block.targetCategory2.displayName)")
                        .font(.caption2).bold()
                    Text("(urgent only)")
                        .font(.caption2).foregroundStyle(.orange)
                    Spacer()
                }
            }

            // Live stats
            if let stats = sessionManager.currentBlockStats, stats.totalEvents > 0 {
                HStack(spacing: 12) {
                    StatPill(label: "Hits", value: "\(stats.hits)", color: .green)
                    StatPill(label: "I-FA", value: "\(stats.intensityFalseAlarms)", color: .orange)
                    StatPill(label: "C-FA", value: "\(stats.categoryFalseAlarms)", color: .red)
                    StatPill(label: "Miss", value: "\(stats.misses)", color: .gray)
                    Spacer()
                }
            }
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Notification Area (Condition-Aware)

    @ViewBuilder
    private var notificationArea: some View {
        if let display = classifier.currentDisplay {
            let condition = sessionManager.activeCondition ?? .animation

            switch condition {
            case .textOnly:
                TextOnlyCard(display: display)

            case .staticIcon:
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(display.category.displayName)
                            .font(.headline)
                        Spacer()
                        ConfidencePill(bucket: display.confidenceBucket)
                    }
                    StaticSoundIcon(category: display.category, intensity: display.intensityLevel)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            case .animation:
                AnimationCard(
                    display: display,
                    pulseID: classifier.pulseIDs[display.category] ?? 0
                )
            }
        } else {
            // Idle / listening state
            VStack(spacing: 8) {
                Text("Listening…")
                    .font(.title3).bold()
                Text("No confident sound detected")
                    .font(.subheadline).foregroundStyle(.secondary)
                if let raw = classifier.latestRaw {
                    Text("Top guess: \(raw.label) • \(String(format: "%.2f", raw.confidence))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        Button {
            classifier.handleConfirmTap()
            // Brief visual feedback
        } label: {
            Text("Confirm Sound")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 10) {
            Button {
                classifier.isListening ? classifier.stop() : classifier.start()
            } label: {
                Text(classifier.isListening ? "Stop" : "Start Listening")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            HStack {
                Text("Haptics")
                Spacer()
                Toggle("", isOn: $classifier.hapticsEnabled).labelsHidden()
            }
        }
    }

    // MARK: - Debug

    private var debugCard: some View {
        Group {
            if let raw = classifier.latestRaw {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Debug (raw classifier)")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text(raw.label).font(.system(.headline, design: .monospaced))
                        Spacer()
                        Text(String(format: "%.3f", raw.confidence))
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(raw.confidence >= 0.40 ? .primary : .secondary)
                    }
                    HStack {
                        if let cat = raw.category {
                            Text("→ \(cat.displayName)")
                                .font(.caption).bold().foregroundStyle(.blue)
                        } else {
                            Text("→ unmapped")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        Spacer()
                        if let display = classifier.currentDisplay {
                            Text(display.intensityLevel.displayName)
                                .font(.caption).bold()
                                .foregroundStyle(display.intensityLevel == .urgent ? .orange : .secondary)
                        }
                        if let cat = classifier.activeCategory {
                            Text("Pulses: \(classifier.pulseIDs[cat] ?? 0)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.thinMaterial.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Condition A: Text-Only Card

private struct TextOnlyCard: View {
    let display: AwarenessDisplayState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Sound Detected")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                ConfidencePill(bucket: display.confidenceBucket)
            }

            // Category label ONLY — no intensity info for text condition
            Text(display.category.displayName)
                .font(.title).bold()

            ProgressView(value: display.confidence)
            Text("Confidence: \(String(format: "%.0f%%", display.confidence * 100))")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Condition B: Static Icon Card

private struct StaticIconCard: View {
    let display: AwarenessDisplayState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Sound Detected")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                ConfidencePill(bucket: display.confidenceBucket)
            }

            HStack(spacing: 16) {
                // Static icon — routine vs urgent variant
                staticIcon
                    .font(.system(size: 56))
                    .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 4) {
                    Text(display.category.displayName)
                        .font(.title3).bold()
                    // Intensity shown through icon visual variant, not text
                }
            }

            ProgressView(value: display.confidence)
            Text("Confidence: \(String(format: "%.0f%%", display.confidence * 100))")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Returns different SF Symbol + styling for routine vs urgent
    @ViewBuilder
    private var staticIcon: some View {
        let isUrgent = display.intensityLevel == .urgent

        switch display.category {
        case .knocking:
            Image(systemName: isUrgent ? "hand.point.up.fill" : "hand.point.up")
                .foregroundStyle(isUrgent ? .red : .primary)
                .scaleEffect(isUrgent ? 1.15 : 0.9)

        case .dogBarking:
            Image(systemName: "dog.fill")
                .foregroundStyle(isUrgent ? .red : .primary)
                .scaleEffect(isUrgent ? 1.15 : 0.9)

        case .babyCrying:
            Image(systemName: isUrgent ? "face.crying.fill" : "face.crying")
                .foregroundStyle(isUrgent ? .red : .primary)
                .scaleEffect(isUrgent ? 1.15 : 0.9)

        case .coughing:
            Image(systemName: isUrgent ? "lungs.fill" : "lungs")
                .foregroundStyle(isUrgent ? .red : .primary)
                .scaleEffect(isUrgent ? 1.15 : 0.9)

        case .glassBreaking:
            Image(systemName: isUrgent ? "broken.glass.fill" : "glass")
                .foregroundStyle(isUrgent ? .red : .primary)
                .scaleEffect(isUrgent ? 1.15 : 0.9)

        case .alarm:
            Image(systemName: isUrgent ? "light.beacon.max.fill" : "light.beacon.min")
                .foregroundStyle(isUrgent ? .red : .orange)
                .scaleEffect(isUrgent ? 1.15 : 0.9)
        }
    }
}

// MARK: - Condition C: Animation Card

private struct AnimationCard: View {
    let display: AwarenessDisplayState
    let pulseID: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(display.category.displayName)
                    .font(.headline)
                Spacer()
                ConfidencePill(bucket: display.confidenceBucket)
                Text("Pulse \(pulseID)")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Use existing animation views
            animationView
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var animationView: some View {
        switch display.category {
        case .knocking:
            KnockAnimationView(pulseID: pulseID, intensity: display.intensityLevel)
        case .dogBarking:
            DogBarkAnimationView(pulseID: pulseID, intensity: display.intensityLevel)
        case .babyCrying:
            BabyCryAnimationView(pulseID: pulseID, intensity: display.intensityLevel)
        case .alarm:
            AlarmAnimationView(pulseID: pulseID, intensity: display.intensityLevel)
        case .coughing:
            CoughAnimationView(pulseID: pulseID, intensity: display.intensityLevel)
        case .glassBreaking:
            GlassBreakAnimationView(pulseID: pulseID, intensity: display.intensityLevel)
        }
    }
}

// MARK: - Placeholder Animation (for coughing + screaming until you build them)

struct PlaceholderAnimationView: View {
    let category: SoundCategory
    let pulseID: Int

    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                )

            VStack(spacing: 8) {
                Image(systemName: category == .coughing ? "lungs.fill" : "megaphone.fill")
                    .font(.system(size: 64))
                    .scaleEffect(scale)
                Text(category.displayName)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(height: 190)
        .onChange(of: pulseID) { _, _ in
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                scale = 1.2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    scale = 1.0
                }
            }
        }
    }
}

// MARK: - Shared Components

private struct ConfidencePill: View {
    let bucket: ConfidenceBucket

    var body: some View {
        Text(bucket.rawValue)
            .font(.caption).bold()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(pillColor)
            .clipShape(Capsule())
    }

    private var pillColor: Color {
        switch bucket {
        case .high: return .green.opacity(0.25)
        case .medium: return .orange.opacity(0.25)
        case .low: return .gray.opacity(0.22)
        }
    }
}

private struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.caption.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Researcher Panel Sheet

private struct ResearcherPanelSheet: View {
    @EnvironmentObject var sessionManager: ExperimentSessionManager
    @EnvironmentObject var classifier: SoundClassifierService

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Session State") {
                    Text("State: \(String(describing: sessionManager.sessionState))")
                    if let block = sessionManager.currentBlock {
                        Text("Block: \(block.blockNumber) — \(block.visualCondition.displayName)")
                        Text("Targets: \(block.targetCategory1.displayName), \(block.targetCategory2.displayName)")
                    }
                }

                if sessionManager.sessionState == .idle {
                    Section("Preview Mode") {
                        Picker("Visual Condition", selection: $sessionManager.previewCondition) {
                            Text("Text Only").tag(VisualCondition.textOnly)
                            Text("Static Icon").tag(VisualCondition.staticIcon)
                            Text("Animation").tag(VisualCondition.animation)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Configure New Session") {
                    TextField("Participant ID", text: $sessionManager.pendingParticipantID)
                    Picker("Condition Order", selection: $sessionManager.pendingOrderIndex) {
                        ForEach(0..<6, id: \.self) { i in
                            let o = ConditionOrder.allOrders[i]
                            Text("\(o.block1.code)-\(o.block2.code)-\(o.block3.code)").tag(i)
                        }
                    }
                    Picker("Target Rotation", selection: $sessionManager.pendingRotation) {
                        ForEach(TargetRotation.allCases, id: \.self) { r in
                            Text("Rotation \(r.rawValue)").tag(r)
                        }
                    }
                    Button("Configure Session") {
                        sessionManager.configureSession(
                            participantID: sessionManager.pendingParticipantID,
                            conditionOrder: ConditionOrder.allOrders[sessionManager.pendingOrderIndex],
                            targetRotation: sessionManager.pendingRotation
                        )
                    }
                    .disabled(sessionManager.pendingParticipantID.isEmpty)
                }

                Section("Session Controls") {
                    switch sessionManager.sessionState {
                    case .configured:
                        Button("Start Training") { sessionManager.startTraining() }
                    case .training:
                        Button("Finish Training → Block 1") { sessionManager.finishTraining() }
                    case .blockReady:
                        Button("Start Block") {
                            if !classifier.isListening { classifier.start() }
                            sessionManager.startBlock()
                        }
                    case .blockActive:
                        Button("End Block") {
                            sessionManager.endBlock()
                            classifier.stop()
                        }
                    case .blockComplete:
                        Button("Proceed to Next") { sessionManager.proceedAfterBlock() }
                    case .sessionComplete:
                        Button("Export Data") { exportData() }
                    default:
                        Text("Configure a session first")
                            .foregroundStyle(.secondary)
                    }

                    if sessionManager.sessionState != .idle {
                        Button("Reset Session", role: .destructive) {
                            classifier.stop()
                            sessionManager.resetSession()
                        }
                    }
                }

                if let stats = sessionManager.currentBlockStats {
                    Section("Block \(stats.blockNumber) Stats") {
                        HStack { Text("Hits"); Spacer(); Text("\(stats.hits)").bold() }
                        HStack { Text("Intensity FA"); Spacer(); Text("\(stats.intensityFalseAlarms)").bold().foregroundStyle(.orange) }
                        HStack { Text("Category FA"); Spacer(); Text("\(stats.categoryFalseAlarms)").bold().foregroundStyle(.red) }
                        HStack { Text("Misses"); Spacer(); Text("\(stats.misses)").bold() }
                        if let rt = stats.meanReactionTimeMs {
                            HStack { Text("Mean RT"); Spacer(); Text("\(Int(rt)) ms").bold() }
                        }
                    }
                }

                Section("Logs") {
                    Text("Detections: \(sessionManager.detectionLogs.count)")
                    Text("Responses: \(sessionManager.responseLogs.count)")
                    Text("Pulses: \(sessionManager.pulseLogs.count)")
                }
            }
            .navigationTitle("Researcher Panel")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func exportData() {
        guard let data = sessionManager.exportSessionData() else { return }
        do {
            let url = try DataExportService.shared.saveToDocuments(data)
            DataExportService.shared.shareFiles([url])
        } catch {
            print("❌ Export failed:", error)
        }
    }
}

// MARK: - Logs Sheet

private struct LogsSheet: View {
    let trustEvents: [TrustEvent]
    let feedback: [UserFeedback]

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Trust Events") {
                    if trustEvents.isEmpty {
                        Text("No events yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(trustEvents) { e in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(e.label).bold()
                                    if let cat = e.category {
                                        Text("(\(cat.displayName))").font(.caption).foregroundStyle(.blue)
                                    }
                                    Spacer()
                                    Text(String(format: "%.2f", e.confidence)).foregroundStyle(.secondary)
                                }
                                Text(e.triggered ? "Triggered" : "Not triggered")
                                    .font(.caption)
                                    .foregroundStyle(e.triggered ? .green : .secondary)
                                Text(e.reason).font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("User Feedback") {
                    if feedback.isEmpty {
                        Text("No feedback yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(feedback) { f in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(f.label).bold()
                                    Text(String(format: "%.2f", f.confidence))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(f.verdict.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(.thinMaterial)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .navigationTitle("Logs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
