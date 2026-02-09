// DogBarkAnimationView.swift
// UPDATE: Replace entire file

import SwiftUI

struct DogBarkAnimationView: View {
    let pulseID: Int
    var intensity: IntensityLevel = .urgent

    @State private var bark = false
    @State private var showWaves = false
    @State private var playToken = UUID()

    // Intensity-driven constants
    private var repeats: Int { intensity == .urgent ? 4 : 1 }
    private var cycleOn: TimeInterval { intensity == .urgent ? 0.12 : 0.20 }
    private var cycleOff: TimeInterval { intensity == .urgent ? 0.08 : 0.30 }
    private var scaleAmount: CGFloat { intensity == .urgent ? 1.22 : 1.03 }
    private var rotationAmount: Double { intensity == .urgent ? -14 : -2 }
    private var liftAmount: CGFloat { intensity == .urgent ? -10 : -1 }
    private var waveScale: CGFloat { intensity == .urgent ? 0.85 : 0.35 }
    private var springResponse: Double { intensity == .urgent ? 0.10 : 0.28 }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let baseSize: CGFloat = min(96, h * 0.72)

            ZStack {
                Image(systemName: "dog")
                    .font(.system(size: baseSize, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .scaleEffect(bark ? scaleAmount : 1.0)
                    .rotationEffect(.degrees(bark ? rotationAmount : 0))
                    .offset(y: bark ? liftAmount : 0)
                    .animation(.spring(response: springResponse, dampingFraction: 0.55), value: bark)

                Image(systemName: intensity == .urgent ? "wave.3.right" : "wave.3.right")
                    .font(.system(size: baseSize * waveScale, weight: .regular))
                    .offset(x: baseSize * 1.2, y: -baseSize * 0.45)
                    .opacity(showWaves ? 1 : 0)
                    .scaleEffect(showWaves ? 1.0 : 0.75)
                    .animation(.easeOut(duration: 0.22), value: showWaves)

                // Extra wave layer for urgent (bigger, behind)
                if intensity == .urgent {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: baseSize * 0.55, weight: .light))
                        .offset(x: baseSize * 1.4, y: -baseSize * 0.35)
                        .opacity(showWaves ? 0.5 : 0)
                        .scaleEffect(showWaves ? 1.1 : 0.7)
                        .animation(.easeOut(duration: 0.28), value: showWaves)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 160)
        .onAppear { playBarkSequence() }
        .onChange(of: pulseID) { _, _ in playBarkSequence() }
        .accessibilityLabel("Dog barking")
    }

    private func playBarkSequence() {
        let token = UUID()
        playToken = token

        for i in 0..<repeats {
            let t = TimeInterval(i) * (cycleOn + cycleOff)

            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                guard playToken == token else { return }
                bark = true
                showWaves = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + t + cycleOn) {
                guard playToken == token else { return }
                bark = false
                showWaves = false
            }
        }
    }
}
