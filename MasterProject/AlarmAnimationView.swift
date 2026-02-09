// AlarmAnimationView.swift
// UPDATE: Replace entire file

import SwiftUI

struct AlarmAnimationView: View {
    let pulseID: Int
    var intensity: IntensityLevel = .urgent

    @State private var visible = false
    @State private var playToken = UUID()
    @State private var bounceTrigger = false
    @State private var waveRing = false

    // Intensity-driven constants
    private var repeats: Int { intensity == .urgent ? 5 : 2 }
    private var cycle: TimeInterval { intensity == .urgent ? 0.22 : 0.50 }
    private var beaconSize: CGFloat { intensity == .urgent ? 92 : 70 }
    private var beaconColor: Color { intensity == .urgent ? .red : .orange }
    private var beaconSymbol: String { intensity == .urgent ? "light.beacon.max.fill" : "light.beacon.min.fill" }
    private var linger: TimeInterval { intensity == .urgent ? 1.0 : 1.5 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                )

            ZStack {
                // Expanding wave rings (urgent only)
                if intensity == .urgent {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(beaconColor.opacity(waveRing ? 0.0 : 0.2), lineWidth: 2)
                            .frame(width: waveRing ? 160 : 60, height: waveRing ? 160 : 60)
                            .animation(
                                .easeOut(duration: 0.8)
                                    .repeatCount(repeats, autoreverses: false)
                                    .delay(Double(i) * 0.2),
                                value: waveRing
                            )
                    }
                }

                Image(systemName: beaconSymbol)
                    .font(.system(size: beaconSize, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(beaconColor)
                    .symbolEffect(.bounce, value: bounceTrigger)
                    .opacity(visible ? 1 : 0)
                    .scaleEffect(visible ? 1.0 : 0.85)
                    .animation(.easeOut(duration: 0.12), value: visible)
            }
        }
        .frame(height: 190)
        .onAppear { playAlarmSequence() }
        .onChange(of: pulseID) { _, _ in playAlarmSequence() }
        .accessibilityLabel("Alarm")
    }

    private func playAlarmSequence() {
        let token = UUID()
        playToken = token

        visible = true
        bounceTrigger = false
        waveRing = false

        // Start wave rings for urgent
        if intensity == .urgent {
            waveRing = true
        }

        for i in 0..<repeats {
            let t = TimeInterval(i) * cycle
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                guard playToken == token else { return }
                bounceTrigger.toggle()
            }
        }

        let total = TimeInterval(repeats) * cycle
        DispatchQueue.main.asyncAfter(deadline: .now() + total + linger) {
            guard playToken == token else { return }
            visible = false
            waveRing = false
        }
    }
}
