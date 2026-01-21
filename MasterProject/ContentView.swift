// ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var classifier = SoundClassifierService()

    @State private var showWhySheet = false
    @State private var showLogSheet = false

    var body: some View {
        ZStack {
            mainUI
                .blur(radius: classifier.doorbellDetected ? 2 : 0)

            if classifier.doorbellDetected {
                DoorbellAnimationView(pulseID: classifier.doorbellPulseID)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: classifier.doorbellDetected)
        .padding()
        .sheet(isPresented: $showWhySheet) {
            WhyThisAlertSheet(events: classifier.recentTrustEvents)
        }
        .sheet(isPresented: $showLogSheet) {
            LogsSheet(trustEvents: classifier.recentTrustEvents, feedback: classifier.feedbackLog)
        }
    }

    private var mainUI: some View {
        VStack(spacing: 16) {
            header

            StatusRow(isListening: classifier.isListening,
                      lastUpdate: classifier.lastUpdate)

            AwarenessCard(
                stable: classifier.stableDisplay,
                raw: classifier.latestRaw,
                bucket: classifier.stableDisplay.map { classifier.confidenceBucket(for: $0.confidence) },
                onWhyTap: { showWhySheet = true },
                onCorrect: { classifier.addFeedback(verdict: .correct) },
                onWrong: { classifier.addFeedback(verdict: .wrong) }
            )

            if !classifier.doorbellDetected {

                if let p = classifier.latestRaw,
                   classifier.isKnockLikeLabel(p.label),
                   !classifier.isKnockSuppressedNow() {
                    KnockCard(pulseID: classifier.knockPulseID)
                }

                // Dog
                if let p = classifier.latestRaw, classifier.isDogLikeLabel(p.label) {
                    DogCard(pulseID: classifier.dogPulseID)
                }

                // Baby
                if let p = classifier.latestRaw, classifier.isBabyLikeLabel(p.label) {
                    BabyCard(pulseID: classifier.babyPulseID)
                }

                // Alarm/Siren
                if let p = classifier.latestRaw, classifier.isAlarmLikeLabel(p.label) {
                    AlarmCard(pulseID: classifier.alarmPulseID)
                }
            }

            controls
            debugCard
            Spacer(minLength: 0)
        }
    }

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

            Button {
                showLogSheet = true
            } label: {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 18, weight: .semibold))
            }
            .accessibilityLabel("Open logs")
        }
    }

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

                Toggle("", isOn: Binding(
                    get: { classifier.hapticsEnabled },
                    set: { classifier.hapticsEnabled = $0 }
                ))
                .labelsHidden()
            }
        }
    }

    private var debugCard: some View {
        Group {
            if let raw = classifier.latestRaw {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Debug (raw classifier)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text(raw.label)
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.2f", raw.confidence))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.thinMaterial.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

// MARK: - Components

private struct StatusRow: View {
    let isListening: Bool
    let lastUpdate: Date?

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .frame(width: 10, height: 10)
                .foregroundStyle(isListening ? .green : .secondary)

            Text(isListening ? "Listening" : "Not listening")
                .foregroundStyle(isListening ? .primary : .secondary)

            Spacer()

            if let d = lastUpdate {
                Text("Updated \(d.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No updates yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AwarenessCard: View {
    let stable: SoundPrediction?
    let raw: SoundPrediction?
    let bucket: ConfidenceBucket?

    let onWhyTap: () -> Void
    let onCorrect: () -> Void
    let onWrong: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Awareness")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Why?") { onWhyTap() }
                    .font(.caption)
            }

            if let p = stable {
                HStack(alignment: .firstTextBaseline) {
                    Text(p.label)
                        .font(.title3).bold()
                    Spacer()
                    ConfidencePill(bucket: bucket ?? .low)
                }

                ProgressView(value: p.confidence)
                Text("Confidence: \(String(format: "%.2f", p.confidence))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Audio stays on your device.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

            } else {
                Text("Listening…")
                    .font(.title3).bold()
                Text("No confident sound event")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let r = raw {
                    Text("Top guess: \(r.label) • \(String(format: "%.2f", r.confidence))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button { onCorrect() } label: {
                    Label("Correct", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.bordered)

                Button { onWrong() } label: {
                    Label("Wrong", systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.bordered)
            }
            .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct ConfidencePill: View {
    let bucket: ConfidenceBucket

    var body: some View {
        Text(bucket.rawValue)
            .font(.caption).bold()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(pillBackground)
            .clipShape(Capsule())
    }

    private var pillBackground: Color {
        switch bucket {
        case .high: return Color.green.opacity(0.25)
        case .medium: return Color.orange.opacity(0.25)
        case .low: return Color.gray.opacity(0.22)
        }
    }
}

private struct KnockCard: View {
    let pulseID: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Knocking").font(.headline)
                Spacer()
                Text("Pulse \(pulseID)").font(.caption).foregroundStyle(.secondary)
            }
            KnockAnimationView(pulseID: pulseID)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct DogCard: View {
    let pulseID: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Dog barking").font(.headline)
                Spacer()
                Text("Pulse \(pulseID)").font(.caption).foregroundStyle(.secondary)
            }
            DogBarkAnimationView(pulseID: pulseID)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct BabyCard: View {
    let pulseID: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Baby crying").font(.headline)
                Spacer()
                Text("Pulse \(pulseID)").font(.caption).foregroundStyle(.secondary)
            }
            BabyCryAnimationView(pulseID: pulseID)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct AlarmCard: View {
    let pulseID: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Emergency siren").font(.headline)
                Spacer()
                Text("Pulse \(pulseID)").font(.caption).foregroundStyle(.secondary)
            }
            AlarmAnimationView(pulseID: pulseID)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Sheets

private struct WhyThisAlertSheet: View {
    let events: [TrustEvent]

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Most recent reasoning")) {
                    if let e = events.first {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(e.triggered ? "Triggered" : "Not triggered").font(.headline)
                            Text("Label: \(e.label)")
                            Text("Confidence: \(String(format: "%.2f", e.confidence))")
                            Text(e.reason).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("No events yet.").foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("How trust cues work")) {
                    Text("• The app shows a sound only after it’s stable for a moment (Awareness card).")
                    Text("• Separate event animations can be fast and appear even at low confidence.")
                    Text("• Eligibility windows + peak detection make events feel real-time.")
                }
            }
            .navigationTitle("Why this?")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { } }
            }
        }
    }
}

private struct LogsSheet: View {
    let trustEvents: [TrustEvent]
    let feedback: [UserFeedback]

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Trust events")) {
                    if trustEvents.isEmpty {
                        Text("No trust events yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(trustEvents) { e in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(e.label).bold()
                                    Spacer()
                                    Text(String(format: "%.2f", e.confidence)).foregroundStyle(.secondary)
                                }
                                Text(e.triggered ? "Triggered" : "Not triggered")
                                    .font(.caption)
                                    .foregroundStyle(e.triggered ? .green : .secondary)
                                Text(e.reason).font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section(header: Text("User feedback")) {
                    if feedback.isEmpty {
                        Text("No feedback yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(feedback) { f in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(f.label).bold()
                                    Text(String(format: "%.2f", f.confidence))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(f.verdict.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.thinMaterial)
                                    .clipShape(Capsule())
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Logs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { } }
            }
        }
    }
}
