import SwiftUI

struct BabyCryAnimationView: View {

    let pulseID: Int

    @State private var playToken = UUID()

    @State private var shakeX: CGFloat = 0
    @State private var sobOn = false
    @State private var tearsOn = false
    @State private var sweatOn = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                )

            GeometryReader { geo in
                let h = geo.size.height
                let base: CGFloat = min(120, h * 0.78)

                BabyFaceIcon(
                    base: base,
                    sobOn: sobOn,
                    tearsOn: tearsOn,
                    sweatOn: sweatOn
                )
                .offset(x: shakeX)
                .animation(.easeOut(duration: 0.06), value: shakeX)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(22)
        }
        .frame(height: 190)
        .onChange(of: pulseID) { _, _ in
            playCrySequence()
        }
        .accessibilityLabel("Baby crying")
    }

    // MARK: - Animation Logic

    private func playCrySequence() {
        let token = UUID()
        playToken = token

        shakeX = 0
        sobOn = false
        tearsOn = false
        sweatOn = false

        // Longer crying:
        // - slower rhythm
        // - more pulses
        let cycle: TimeInterval = 0.34
        let repeats = 6

        for i in 0..<repeats {
            let t = TimeInterval(i) * cycle

            // ON: sob + effects + shake
            DispatchQueue.main.asyncAfter(deadline: .now() + t + 0.00) {
                guard playToken == token else { return }
                sobOn = true
                tearsOn = true
                sweatOn = true
                shakeX = (i % 2 == 0) ? -3 : 3
            }

            // Soften: mouth relax a bit, stop shake
            DispatchQueue.main.asyncAfter(deadline: .now() + t + 0.18) {
                guard playToken == token else { return }
                sobOn = false
                shakeX = 0
            }

            // Pop OFF so next cycle "reappears"
            DispatchQueue.main.asyncAfter(deadline: .now() + t + 0.28) {
                guard playToken == token else { return }
                tearsOn = false
                sweatOn = false
            }
        }

        // End state (neutral face)
        let total = TimeInterval(repeats) * cycle
        let linger: TimeInterval = 0.6

        DispatchQueue.main.asyncAfter(deadline: .now() + total + linger) {
            guard playToken == token else { return }
            sobOn = false
            tearsOn = false
            sweatOn = false
            shakeX = 0
        }
    }
}

// MARK: - Tailor-made icon (no SF symbols)

private struct BabyFaceIcon: View {
    let base: CGFloat
    let sobOn: Bool
    let tearsOn: Bool
    let sweatOn: Bool

    var body: some View {
        let face = base * 0.92
        let stroke = max(2, base * 0.045)

        ZStack {
            // Face outline
            Circle()
                .stroke(.primary.opacity(0.88), lineWidth: stroke)
                .frame(width: face, height: face)

            // Ears
            Circle()
                .stroke(.primary.opacity(0.88), lineWidth: stroke)
                .frame(width: face * 0.20, height: face * 0.20)
                .offset(x: -face * 0.56, y: 0)

            Circle()
                .stroke(.primary.opacity(0.88), lineWidth: stroke)
                .frame(width: face * 0.20, height: face * 0.20)
                .offset(x: face * 0.56, y: 0)

            // Hair curl
            HairCurl()
                .stroke(.primary.opacity(0.88),
                        style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round))
                .frame(width: face * 0.28, height: face * 0.28)
                .offset(y: -face * 0.52)

            // Eyes squeezed shut
            EyeSquints()
                .stroke(.primary.opacity(0.88),
                        style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .frame(width: face * 0.46, height: face * 0.20)
                .offset(y: -face * 0.10)

            // Mouth (pulses larger when sobbing)
            MouthOval()
                .stroke(.primary.opacity(0.88),
                        style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round))
                .frame(width: face * (sobOn ? 0.36 : 0.28),
                       height: face * (sobOn ? 0.24 : 0.18))
                .offset(y: face * 0.18)
                .animation(.easeInOut(duration: 0.12), value: sobOn)

            // Sweat drops (primary)
            Group {
                SweatDrop()
                    .fill(.primary.opacity(0.88))
                    .frame(width: face * 0.08, height: face * 0.11)
                    .offset(x: -face * 0.38, y: -face * 0.36)

                SweatDrop()
                    .fill(.primary.opacity(0.88))
                    .frame(width: face * 0.07, height: face * 0.10)
                    .offset(x: face * 0.40, y: -face * 0.34)
            }
            .opacity(sweatOn ? 1 : 0)
            .scaleEffect(sweatOn ? 1.0 : 0.85)
            .animation(.easeOut(duration: 0.14), value: sweatOn)

            // Tears (BLUE)
            Group {
                TearDrop()
                    .fill(Color.blue.opacity(0.85))
                    .frame(width: face * 0.10, height: face * 0.16)
                    .offset(x: -face * 0.23, y: face * 0.02)

                TearDrop()
                    .fill(Color.blue.opacity(0.85))
                    .frame(width: face * 0.10, height: face * 0.16)
                    .offset(x: face * 0.23, y: face * 0.02)
            }
            .opacity(tearsOn ? 1 : 0)
            .offset(y: tearsOn ? face * 0.06 : 0)
            .animation(.easeOut(duration: 0.14), value: tearsOn)
        }
    }
}

// MARK: - Shapes

private struct HairCurl: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) * 0.45

        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addCurve(to: CGPoint(x: c.x + r, y: c.y),
                   control1: CGPoint(x: c.x + r * 0.85, y: c.y - r * 0.85),
                   control2: CGPoint(x: c.x + r, y: c.y - r * 0.10))
        p.addCurve(to: CGPoint(x: c.x, y: c.y + r * 0.35),
                   control1: CGPoint(x: c.x + r, y: c.y + r * 0.75),
                   control2: CGPoint(x: c.x + r * 0.25, y: c.y + r * 0.65))
        p.addCurve(to: CGPoint(x: c.x - r * 0.28, y: c.y + r * 0.05),
                   control1: CGPoint(x: c.x - r * 0.25, y: c.y + r * 0.10),
                   control2: CGPoint(x: c.x - r * 0.35, y: c.y + r * 0.10))
        return p
    }
}

private struct EyeSquints: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()

        // Left
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.midY + rect.height * 0.18))
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.midY - rect.height * 0.18))

        // Right
        p.move(to: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.26, y: rect.midY + rect.height * 0.18))
        p.move(to: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.26, y: rect.midY - rect.height * 0.18))

        return p
    }
}

private struct MouthOval: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: rect)
        return p
    }
}

private struct TearDrop: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let top = CGPoint(x: rect.midX, y: rect.minY)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY)
        let left = CGPoint(x: rect.minX, y: rect.midY)
        let right = CGPoint(x: rect.maxX, y: rect.midY)

        p.move(to: top)
        p.addQuadCurve(to: left, control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25))
        p.addQuadCurve(to: bottom, control: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.maxY))
        p.addQuadCurve(to: right, control: CGPoint(x: rect.maxX - rect.width * 0.20, y: rect.maxY))
        p.addQuadCurve(to: top, control: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25))
        return p
    }
}

private struct SweatDrop: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let top = CGPoint(x: rect.midX, y: rect.minY)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY)

        p.move(to: top)
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY),
                       control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25))
        p.addQuadCurve(to: bottom,
                       control: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                       control: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.maxY))
        p.addQuadCurve(to: top,
                       control: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25))
        return p
    }
}
