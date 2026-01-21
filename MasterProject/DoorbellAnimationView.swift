import SwiftUI


struct DoorbellAnimationView: View {
    let pulseID: Int

    // Token prevents old scheduled events from cutting off new ones
    @State private var playToken = UUID()

    // Motion states
    @State private var fingerUp = false
    @State private var buttonPressed = false
    @State private var wavesOn = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                )

            GeometryReader { geo in
                let h = geo.size.height
                let base: CGFloat = min(120, h * 0.78)

                // === Layout anchors ===
                let doorX = -base * 0.55
                let plateX = base * 0.45

                // Top bell circle and lower press button
                let bellCenterX = plateX
                let bellCenterY: CGFloat = -base * 0.14

                let pressCenterX = plateX
                let pressCenterY: CGFloat = base * 0.22

                // Sizes
                let doorW = base * 0.85
                let doorH = base * 1.25

                let plateW = base * 0.58
                let plateH = base * 0.78

                let bellCircleSize = base * 0.33
                let bellIconSize = base * 0.22

                let pressCircleSize = base * 0.26

                // Hand: lower start + hits the small circle
                let handSize = base * 0.58
                let handRestY = base * 0.80
                let handPressY = pressCenterY + base * 0.28

                // Waves originate from bell
                let wavesSize = base * 0.40

                ZStack {
                    // ======================
                    // DOOR (LEFT)
                    // ======================
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.primary.opacity(0.10))
                        .frame(width: doorW, height: doorH)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(.primary.opacity(0.15), lineWidth: 1)
                        )
                        .offset(x: doorX)

                    Circle()
                        .fill(.primary.opacity(0.25))
                        .frame(width: base * 0.08, height: base * 0.08)
                        .offset(x: doorX + doorW * 0.18, y: base * 0.10)

                    // ======================
                    // PLATE (RIGHT)
                    // ======================
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.primary.opacity(0.06))
                        .frame(width: plateW, height: plateH)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(.primary.opacity(0.12), lineWidth: 1)
                        )
                        .offset(x: plateX)

                    // ======================
                    // TOP: BELL CIRCLE
                    // ======================
                    ZStack {
                        Circle()
                            .stroke(.primary.opacity(0.22), lineWidth: base * 0.016)
                            .frame(width: bellCircleSize * 1.05, height: bellCircleSize * 1.05)

                        Circle()
                            .fill(.primary.opacity(0.10))
                            .frame(width: bellCircleSize, height: bellCircleSize)

                        Image(systemName: "bell.fill")
                            .font(.system(size: bellIconSize, weight: .semibold))
                            .symbolRenderingMode(.monochrome)
                            .opacity(0.95)
                            // tiny "ring" wobble when waves are on (subtle realism)
                            .rotationEffect(.degrees(wavesOn ? -6 : 0))
                            .animation(.easeInOut(duration: 0.10), value: wavesOn)
                    }
                    .offset(x: bellCenterX, y: bellCenterY)

                    // ======================
                    // BOTTOM: PRESS BUTTON (SMALL)
                    // ======================
                    Circle()
                        .stroke(.primary.opacity(0.22), lineWidth: base * 0.016)
                        .frame(width: pressCircleSize * 0.70, height: pressCircleSize * 0.70)
                        .scaleEffect(buttonPressed ? 0.86 : 1.0)
                        .offset(x: pressCenterX,
                                y: buttonPressed ? (pressCenterY + base * 0.028) : pressCenterY)
                        .animation(.easeOut(duration: 0.10), value: buttonPressed)

                    // ======================
                    // WAVES (UP FROM BELL)
                    // ======================
                    Image(systemName: "wave.3.up")
                        .font(.system(size: wavesSize, weight: .regular))
                        .opacity(wavesOn ? 1 : 0)
                        .scaleEffect(wavesOn ? 1.0 : 0.82)
                        .offset(x: bellCenterX, y: bellCenterY - base * 0.42)
                        .animation(.easeOut(duration: 0.18), value: wavesOn)

                    // ======================
                    // HAND (HITS LOWER BUTTON)
                    // ======================
                    Image(systemName: "hand.point.up.fill")
                        .font(.system(size: handSize, weight: .regular))
                        .symbolRenderingMode(.monochrome)
                        .offset(x: pressCenterX + base * 0.08,
                                y: fingerUp ? handPressY : handRestY)
                        .animation(.easeInOut(duration: 0.18), value: fingerUp)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .padding(25)
        }
        .frame(height: 190)
        .onAppear { playDoorbellSequence() }
        .onChange(of: pulseID) { _, _ in playDoorbellSequence() }
        .accessibilityLabel("Doorbell pressed")
    }

    // MARK: - Animation Logic
    // 3 presses, SPACED OUT so it continues for ~3.3s.

    private func playDoorbellSequence() {
        let token = UUID()
        playToken = token

        // Reset
        fingerUp = false
        buttonPressed = false
        wavesOn = false

        // One "press cycle" timing
        // Total per cycle ≈ 0.45s of motion + ~0.65s rest = ~1.10s
        // 3 cycles ≈ 3.30s of continuous animation
        let cycleSpacing: TimeInterval = 1.10
        let repeats = 3

        for i in 0..<repeats {
            let t = TimeInterval(i) * cycleSpacing

            // approach
            DispatchQueue.main.asyncAfter(deadline: .now() + t + 0.00) {
                guard playToken == token else { return }
                fingerUp = true
            }

            // press + ring
            DispatchQueue.main.asyncAfter(deadline: .now() + t + 0.12) {
                guard playToken == token else { return }
                buttonPressed = true
                wavesOn = true
            }

            // release + stop waves
            DispatchQueue.main.asyncAfter(deadline: .now() + t + 0.28) {
                guard playToken == token else { return }
                buttonPressed = false
                wavesOn = false
            }

            // retract
            DispatchQueue.main.asyncAfter(deadline: .now() + t + 0.40) {
                guard playToken == token else { return }
                fingerUp = false
            }
        }
    }
}
