import SwiftUI


struct KnockAnimationView: View {
    let pulseID: Int

    @State private var armHit: CGFloat = 0
    @State private var doorShake: CGFloat = 0
    @State private var showImpact: Bool = false

    @State private var playToken = UUID()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                )

            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let scale = size / 180

                ZStack {
                    // Door
                    DoorWithFrame()
                        .fill(.primary.opacity(0.92), style: FillStyle(eoFill: true))
                        .frame(width: 70 * scale, height: 130 * scale)
                        .offset(x: 46 * scale + doorShake)

                    // Person
                    PersonKnockingIcon(hitProgress: armHit)
                        .fill(.primary.opacity(0.92))
                        .frame(width: 120 * scale, height: 150 * scale)
                        .offset(x: -18 * scale, y: 8 * scale)

                    // Impact ripple
                    Circle()
                        .stroke(.primary.opacity(0.25), lineWidth: 2 * scale)
                        .frame(width: 36 * scale, height: 36 * scale)
                        .scaleEffect(showImpact ? 1.15 : 0.6)
                        .opacity(showImpact ? 0 : 1)
                        .offset(x: 64 * scale, y: -10 * scale)
                        .animation(.easeOut(duration: 0.25), value: showImpact)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(20)
        }
        .frame(height: 190)
        .onChange(of: pulseID) { _, _ in
            playTripleKnock()
        }
        .accessibilityLabel("Knocking on door visualization")
    }

    // MARK: - Triple knock (3 rounds per pulse, same pace per round)

    private func playTripleKnock() {
        let token = UUID()
        playToken = token

        // Same “feel” as your original, just repeated
        let cycle: TimeInterval = 0.28   // spacing between knock starts
        let repeats = 3

        for i in 0..<repeats {
            let t = TimeInterval(i) * cycle
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                guard playToken == token else { return }
                playSingleKnock()
            }
        }
    }

    // MARK: - One knock (your original animation)

    private func playSingleKnock() {
        // Arm hit
        withAnimation(.spring(response: 0.18, dampingFraction: 0.6)) {
            armHit = 1
        }

        // Door shake
        doorShake = -5
        withAnimation(.easeOut(duration: 0.08)) {
            doorShake = 3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            doorShake = 0
        }

        // Impact ripple
        showImpact = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            showImpact = false
        }

        // Arm reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                armHit = 0
            }
        }
    }
}

//
// MARK: - Door
//

private struct DoorWithFrame: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()

        let outer = rect
        let inner = rect.insetBy(dx: rect.width * 0.12,
                                 dy: rect.height * 0.07)

        let corner = min(rect.width, rect.height) * 0.14

        // Frame
        p.addRoundedRect(in: outer,
                         cornerSize: CGSize(width: corner, height: corner))

        // Inner cutout
        p.addRoundedRect(in: inner,
                         cornerSize: CGSize(width: corner * 0.7, height: corner * 0.7))

        // Handle
        let handleWidth = rect.width * 0.12
        let handleHeight = rect.height * 0.06
        let handleX = rect.maxX - handleWidth * 1.6
        let handleY = rect.midY - handleHeight / 2

        p.addRoundedRect(
            in: CGRect(x: handleX, y: handleY,
                       width: handleWidth, height: handleHeight),
            cornerSize: CGSize(width: handleHeight / 2, height: handleHeight / 2)
        )

        return p
    }
}

//
// MARK: - Person
//

private struct PersonKnockingIcon: Shape {
    var hitProgress: CGFloat // 0...1

    var animatableData: CGFloat {
        get { hitProgress }
        set { hitProgress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width,
                    y: rect.minY + y * rect.height)
        }

        // Head
        let headCenter = pt(0.32, 0.18)
        let headR = rect.width * 0.11
        p.addEllipse(in: CGRect(x: headCenter.x - headR,
                                y: headCenter.y - headR,
                                width: headR * 2,
                                height: headR * 2))

        // Torso
        p.addRoundedRect(
            in: CGRect(x: rect.minX + rect.width * 0.18,
                       y: rect.minY + rect.height * 0.30,
                       width: rect.width * 0.30,
                       height: rect.height * 0.34),
            cornerSize: CGSize(width: rect.width * 0.1, height: rect.width * 0.1)
        )

        // Legs
        p.addRoundedRect(
            in: CGRect(x: rect.minX + rect.width * 0.20,
                       y: rect.minY + rect.height * 0.66,
                       width: rect.width * 0.14,
                       height: rect.height * 0.30),
            cornerSize: CGSize(width: rect.width * 0.08, height: rect.width * 0.08)
        )

        p.addRoundedRect(
            in: CGRect(x: rect.minX + rect.width * 0.32,
                       y: rect.minY + rect.height * 0.66,
                       width: rect.width * 0.14,
                       height: rect.height * 0.30),
            cornerSize: CGSize(width: rect.width * 0.08, height: rect.width * 0.08)
        )

        // Arm
        let shoulder = pt(0.44, 0.38)
        let elbow = pt(0.58, 0.46)
        let wrist = pt(
            lerp(0.70, 0.82, hitProgress),
            lerp(0.48, 0.42, hitProgress)
        )

        p.addPath(line(from: shoulder, to: elbow, width: rect.width * 0.09))
        p.addPath(line(from: elbow, to: wrist, width: rect.width * 0.09))

        // Hand
        let handR = rect.width * 0.045
        p.addEllipse(in: CGRect(x: wrist.x - handR,
                                y: wrist.y - handR,
                                width: handR * 2,
                                height: handR * 2))

        return p
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private func line(from a: CGPoint, to b: CGPoint, width: CGFloat) -> Path {
        var p = Path()
        p.move(to: a)
        p.addLine(to: b)
        return p.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round))
    }
}
