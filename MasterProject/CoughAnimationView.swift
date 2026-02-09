// CoughAnimationView.swift
// UPDATE: Replace entire file

import SwiftUI

struct CoughAnimationView: View {
    let pulseID: Int
    var intensity: IntensityLevel = .urgent

    @State private var playToken = UUID()
    @State private var leanForward: CGFloat = 0
    @State private var shoulderHunch: CGFloat = 0
    @State private var handToMouth: CGFloat = 0
    @State private var chestCompress: CGFloat = 0
    @State private var showCoughBurst: Bool = false
    @State private var shakeX: CGFloat = 0

    // Intensity-driven constants — SAME SPEED, different severity
    private var repeats: Int { intensity == .urgent ? 4 : 3 }
    private var cycle: TimeInterval { 0.36 } // same speed
    private var leanMax: CGFloat { intensity == .urgent ? 1.0 : 0.40 }
    private var shoulderMax: CGFloat { intensity == .urgent ? 1.0 : 0.30 }
    private var shakeAmount: CGFloat { intensity == .urgent ? 4 : 1.5 }
    private var leanRecover: CGFloat { intensity == .urgent ? 0.25 : 0.05 }
    private var springSpeed: Double { 0.12 } // same speed
    // Cloud puff counts differ by intensity
    private var puffCount: Int { intensity == .urgent ? 5 : 3 }
    private var puffMaxSize: CGFloat { intensity == .urgent ? 22 : 14 }
    private var puffSpread: CGFloat { intensity == .urgent ? 1.3 : 1.0 }

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
                let scale = base / 120

                ZStack {
                    CoughingPersonShape(
                        leanProgress: leanForward,
                        handProgress: handToMouth,
                        shoulderProgress: shoulderHunch
                    )
                    .fill(.primary.opacity(0.92))
                    .frame(width: 100 * scale, height: 150 * scale)
                    .offset(x: -10 * scale + shakeX)
                    .animation(.easeOut(duration: 0.06), value: shakeX)

                    // Cloud puffs — visible breath/air expelled from mouth
                    CoughCloudView(
                        visible: showCoughBurst,
                        scale: scale,
                        puffCount: puffCount,
                        maxSize: puffMaxSize,
                        spread: puffSpread,
                        isUrgent: intensity == .urgent
                    )
                    .offset(x: 38 * scale, y: -28 * scale)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(20)
        }
        .frame(height: 190)
        .onAppear { playCoughSequence() }
        .onChange(of: pulseID) { _, _ in playCoughSequence() }
        .accessibilityLabel("Coughing visualization")
    }

    private func playCoughSequence() {
        let token = UUID()
        playToken = token

        leanForward = 0; shoulderHunch = 0; handToMouth = 0
        chestCompress = 0; showCoughBurst = false; shakeX = 0

        withAnimation(.easeIn(duration: 0.10)) { handToMouth = 1 }

        for i in 0..<repeats {
            let t = TimeInterval(i) * cycle + 0.10

            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                guard playToken == token else { return }
                withAnimation(.spring(response: springSpeed, dampingFraction: 0.5)) {
                    leanForward = leanMax
                    shoulderHunch = shoulderMax
                    chestCompress = 1
                }
                showCoughBurst = true
                shakeX = (i % 2 == 0) ? -shakeAmount : shakeAmount
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + t + cycle * 0.44) {
                guard playToken == token else { return }
                withAnimation(.spring(response: 0.14, dampingFraction: 0.7)) {
                    leanForward = leanRecover
                    shoulderHunch = leanRecover * 1.5
                    chestCompress = 0
                }
                showCoughBurst = false
                shakeX = 0
            }
        }

        let total = TimeInterval(repeats) * cycle + 0.10
        DispatchQueue.main.asyncAfter(deadline: .now() + total + 0.3) {
            guard playToken == token else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                leanForward = 0; shoulderHunch = 0; handToMouth = 0; chestCompress = 0
            }
        }
    }
}

// MARK: - Cough Cloud View (replaces old CoughBurstView)

private struct CoughCloudView: View {
    let visible: Bool
    let scale: CGFloat
    var puffCount: Int = 4
    var maxSize: CGFloat = 18
    var spread: CGFloat = 1.0
    var isUrgent: Bool = false

    // Pre-defined puff positions — spread outward and slightly upward from mouth
    private var puffData: [(dx: CGFloat, dy: CGFloat, size: CGFloat, delay: Double)] {
        let base: [(dx: CGFloat, dy: CGFloat, size: CGFloat, delay: Double)] = [
            (dx: 8,  dy: -2,  size: 0.55, delay: 0.00),  // closest to mouth — small
            (dx: 20, dy: -6,  size: 0.75, delay: 0.03),  // expanding
            (dx: 34, dy: -3,  size: 1.00, delay: 0.06),  // biggest in middle
            (dx: 48, dy: -8,  size: 0.85, delay: 0.09),  // dispersing
            (dx: 60, dy: -1,  size: 0.60, delay: 0.12),  // fading away
        ]
        return Array(base.prefix(puffCount))
    }

    var body: some View {
        ZStack {
            // Cloud puffs — each is a soft ellipse that looks like expelled breath
            ForEach(0..<puffCount, id: \.self) { i in
                let data = puffData[i]
                let puffSize = maxSize * data.size * scale

                // Each "puff" is a cluster of overlapping circles for a cloud look
                CloudPuff()
                    .fill(.primary.opacity(visible ? (isUrgent ? 0.30 : 0.20) : 0))
                    .frame(width: puffSize * 1.4, height: puffSize)
                    .offset(
                        x: visible ? data.dx * scale * spread : 4 * scale,
                        y: visible ? data.dy * scale * spread : 0
                    )
                    .scaleEffect(visible ? 1.0 : 0.3)
                    .animation(
                        .easeOut(duration: 0.28).delay(data.delay),
                        value: visible
                    )
            }

            // Small speed lines near mouth (showing force of expulsion)
            ForEach(0..<3, id: \.self) { i in
                Rectangle()
                    .fill(.primary.opacity(visible ? 0.25 : 0))
                    .frame(width: visible ? CGFloat(10 + i * 5) * scale : 2 * scale,
                           height: 1.2 * scale)
                    .offset(
                        x: visible ? CGFloat(6 + i * 10) * scale * spread : 4 * scale,
                        y: CGFloat(-4 + i * 4) * scale
                    )
                    .animation(
                        .easeOut(duration: 0.20).delay(Double(i) * 0.02),
                        value: visible
                    )
            }

            // Extra large diffuse cloud for urgent (shows more expelled air)
            if isUrgent {
                Ellipse()
                    .fill(.primary.opacity(visible ? 0.08 : 0))
                    .frame(width: 50 * scale, height: 28 * scale)
                    .offset(
                        x: visible ? 38 * scale * spread : 10 * scale,
                        y: -4 * scale
                    )
                    .scaleEffect(visible ? 1.1 : 0.4)
                    .animation(.easeOut(duration: 0.35).delay(0.06), value: visible)
            }
        }
    }
}

// MARK: - Cloud Puff Shape (soft cloud-like blob)

private struct CloudPuff: Shape {
    func path(in rect: CGRect) -> Path {
        // Three overlapping circles to create a cloud/puff shape
        var p = Path()
        let w = rect.width
        let h = rect.height

        // Left blob
        p.addEllipse(in: CGRect(
            x: rect.minX,
            y: rect.minY + h * 0.15,
            width: w * 0.50,
            height: h * 0.70
        ))
        // Center blob (largest)
        p.addEllipse(in: CGRect(
            x: rect.minX + w * 0.20,
            y: rect.minY,
            width: w * 0.55,
            height: h
        ))
        // Right blob
        p.addEllipse(in: CGRect(
            x: rect.minX + w * 0.45,
            y: rect.minY + h * 0.10,
            width: w * 0.55,
            height: h * 0.75
        ))
        return p
    }
}

// MARK: - Coughing Person Shape

private struct CoughingPersonShape: Shape {
    var leanProgress: CGFloat
    var handProgress: CGFloat
    var shoulderProgress: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(leanProgress, handProgress), shoulderProgress) }
        set {
            leanProgress = newValue.first.first
            handProgress = newValue.first.second
            shoulderProgress = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }

        let leanX = leanProgress * 0.12
        let leanY = leanProgress * 0.05
        let shoulderLift = shoulderProgress * -0.04

        let headCenter = pt(0.42 + leanX, 0.14 + leanY)
        let headR = rect.width * 0.10
        p.addEllipse(in: CGRect(x: headCenter.x - headR, y: headCenter.y - headR,
                                width: headR * 2, height: headR * 2))

        p.addPath(line(from: pt(0.42 + leanX * 0.7, 0.22 + leanY * 0.7),
                       to: pt(0.42 + leanX * 0.4, 0.27), width: rect.width * 0.06))

        let torsoTop = 0.27 + shoulderLift
        p.addRoundedRect(
            in: CGRect(x: rect.minX + rect.width * (0.28 + leanX * 0.3),
                       y: rect.minY + rect.height * torsoTop,
                       width: rect.width * 0.28, height: rect.height * 0.32),
            cornerSize: CGSize(width: rect.width * 0.08, height: rect.width * 0.08))

        let sY = torsoTop + shoulderLift
        p.addEllipse(in: CGRect(x: rect.minX + rect.width * (0.22 + leanX * 0.2),
                                y: rect.minY + rect.height * sY,
                                width: rect.width * 0.12, height: rect.height * 0.06))
        p.addEllipse(in: CGRect(x: rect.minX + rect.width * (0.50 + leanX * 0.3),
                                y: rect.minY + rect.height * sY,
                                width: rect.width * 0.12, height: rect.height * 0.06))

        p.addRoundedRect(in: CGRect(x: rect.minX + rect.width * 0.30, y: rect.minY + rect.height * 0.62,
                                     width: rect.width * 0.12, height: rect.height * 0.34),
                         cornerSize: CGSize(width: rect.width * 0.06, height: rect.width * 0.06))
        p.addRoundedRect(in: CGRect(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.62,
                                     width: rect.width * 0.12, height: rect.height * 0.34),
                         cornerSize: CGSize(width: rect.width * 0.06, height: rect.width * 0.06))

        // Right arm to mouth
        let shoulder = pt(0.52 + leanX * 0.3, 0.32 + shoulderLift)
        let elbow = CGPoint(x: lerp(pt(0.62, 0.48).x, pt(0.58 + leanX, 0.28 + leanY).x, handProgress),
                            y: lerp(pt(0.62, 0.48).y, pt(0.58 + leanX, 0.28 + leanY).y, handProgress))
        let hand = CGPoint(x: lerp(pt(0.65, 0.52).x, pt(0.48 + leanX, 0.18 + leanY).x, handProgress),
                           y: lerp(pt(0.65, 0.52).y, pt(0.48 + leanX, 0.18 + leanY).y, handProgress))

        p.addPath(line(from: shoulder, to: elbow, width: rect.width * 0.07))
        p.addPath(line(from: elbow, to: hand, width: rect.width * 0.07))
        let handR = rect.width * 0.04
        p.addEllipse(in: CGRect(x: hand.x - handR, y: hand.y - handR, width: handR * 2, height: handR * 2))

        // Left arm
        let lShoulder = pt(0.26 + leanX * 0.2, 0.32 + shoulderLift)
        let lElbow = pt(0.18, lerp(0.46, 0.40, leanProgress))
        let lHand = pt(lerp(0.16, 0.30, leanProgress), lerp(0.54, 0.44, leanProgress))
        p.addPath(line(from: lShoulder, to: lElbow, width: rect.width * 0.07))
        p.addPath(line(from: lElbow, to: lHand, width: rect.width * 0.07))
        p.addEllipse(in: CGRect(x: lHand.x - handR, y: lHand.y - handR, width: handR * 2, height: handR * 2))

        return p
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
    private func line(from a: CGPoint, to b: CGPoint, width: CGFloat) -> Path {
        var p = Path(); p.move(to: a); p.addLine(to: b)
        return p.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round))
    }
}
