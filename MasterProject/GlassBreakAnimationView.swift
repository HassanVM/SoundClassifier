// GlassBreakAnimationView.swift
// UPDATE: Replace entire file

import SwiftUI

struct GlassBreakAnimationView: View {
    let pulseID: Int
    var intensity: IntensityLevel = .urgent

    // Static cooldown — survives view recreation by SwiftUI
    private static var lastShatterTime: Date = .distantPast
    private static let cooldownSeconds: TimeInterval = 5.0

    @State private var playToken = UUID()
    @State private var glassTilt: CGFloat = 0
    @State private var glassFall: CGFloat = 0
    @State private var glassVisible: Bool = true
    @State private var impactFlash: Bool = false
    @State private var shardsLaunched: Bool = false
    @State private var shakeY: CGFloat = 0
    @State private var hasPlayedOnce: Bool = false

    // Intensity-driven constants
    // Routine = slow dramatic tip, fall, shatter
    // Urgent = near-instant smash with massive debris
    private var tipDuration: TimeInterval { intensity == .urgent ? 0.06 : 0.18 }
    private var fallDelay: TimeInterval { intensity == .urgent ? 0.08 : 0.22 }
    private var impactDelay: TimeInterval { intensity == .urgent ? 0.12 : 0.38 }
    private var shardCount: Int { intensity == .urgent ? 10 : 5 }
    private var shakeAmount: CGFloat { intensity == .urgent ? 8 : 4 }
    private var shardSpread: CGFloat { intensity == .urgent ? 1.4 : 0.8 }
    private var shardStiffness: Double { intensity == .urgent ? 90 : 60 }
    private var showSplash: Bool { true }
    private var splashCount: Int { intensity == .urgent ? 8 : 3 }
    private var showFloorCracks: Bool { intensity == .urgent }
    private var showImpactLines: Bool { intensity == .urgent }
    private var dustCount: Int { intensity == .urgent ? 8 : 3 }

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
                    // Floor line — Rectangle centers properly in ZStack (Path does not)
                    Rectangle()
                        .fill(.primary.opacity(0.25))
                        .frame(width: 140 * scale, height: 1.5 * scale)
                        .offset(y: 48 * scale + shakeY)

                    // Intact glass
                    if glassVisible {
                        DrinkingGlassShape()
                            .stroke(.primary.opacity(0.85),
                                    style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round, lineJoin: .round))
                            .frame(width: 40 * scale, height: 60 * scale)
                            .rotationEffect(.degrees(Double(glassTilt) * 90), anchor: .bottom)
                            .offset(y: -10 * scale + glassFall * 50 * scale)
                            .animation(.easeIn(duration: 0.18), value: glassFall)

                        DrinkingGlassFill()
                            .fill(.primary.opacity(0.08))
                            .frame(width: 40 * scale, height: 60 * scale)
                            .rotationEffect(.degrees(Double(glassTilt) * 90), anchor: .bottom)
                            .offset(y: -10 * scale + glassFall * 50 * scale)
                            .animation(.easeIn(duration: 0.18), value: glassFall)
                    }

                    // Impact flash
                    if impactFlash {
                        Circle()
                            .fill(.primary.opacity(intensity == .urgent ? 0.3 : 0.15))
                            .frame(width: 30 * scale, height: 16 * scale)
                            .scaleEffect(x: 2.0, y: 0.6)
                            .offset(y: 44 * scale)
                    }

                    // Shards
                    ForEach(0..<shardCount, id: \.self) { i in
                        GlassShardShape(variant: i)
                            .fill(.primary.opacity(shardsLaunched ? shardOpacity(i) : 0))
                            .frame(width: CGFloat(shardSize(i).w) * scale,
                                   height: CGFloat(shardSize(i).h) * scale)
                            .offset(
                                x: shardsLaunched ? shardFinalPos(i).x * shardSpread * scale : 0,
                                y: shardsLaunched ? shardFinalPos(i).y * shardSpread * scale : 44 * scale
                            )
                            .rotationEffect(.degrees(shardsLaunched ? Double(i * 36 + 10) : 0))
                            .animation(
                                .interpolatingSpring(stiffness: shardStiffness, damping: 6)
                                    .delay(Double(i) * 0.015),
                                value: shardsLaunched
                            )
                    }

                    // Dust
                    ForEach(0..<dustCount, id: \.self) { i in
                        Circle()
                            .fill(.primary.opacity(shardsLaunched ? 0.4 : 0))
                            .frame(width: 2.5 * scale, height: 2.5 * scale)
                            .offset(
                                x: shardsLaunched ? dustOffset(i).x * scale : 0,
                                y: shardsLaunched ? dustOffset(i).y * scale : 44 * scale
                            )
                            .animation(.easeOut(duration: 0.4).delay(Double(i) * 0.02), value: shardsLaunched)
                    }

                    // Liquid splash droplets
                    if showSplash {
                        ForEach(0..<splashCount, id: \.self) { i in
                            SplashDroplet()
                                .fill(.primary.opacity(shardsLaunched ? 0.35 : 0))
                                .frame(width: CGFloat(4 + i % 3) * scale,
                                       height: CGFloat(6 + i % 2 * 3) * scale)
                                .offset(
                                    x: shardsLaunched ? splashOffset(i).x * scale * shardSpread : 0,
                                    y: shardsLaunched ? splashOffset(i).y * scale : 44 * scale
                                )
                                .animation(
                                    .interpolatingSpring(stiffness: 60, damping: 5)
                                        .delay(Double(i) * 0.03),
                                    value: shardsLaunched
                                )
                        }
                    }

                    // Floor crack lines
                    if showFloorCracks && shardsLaunched {
                        FloorCrackLines()
                            .stroke(.primary.opacity(0.3),
                                    style: StrokeStyle(lineWidth: 1.2 * scale, lineCap: .round))
                            .frame(width: 80 * scale, height: 12 * scale)
                            .offset(y: 50 * scale)
                            .transition(.opacity)
                    }

                    // Impact lines radiating from contact point (urgent only)
                    if showImpactLines {
                        ForEach(0..<6, id: \.self) { i in
                            ImpactLine()
                                .stroke(.primary.opacity(shardsLaunched ? 0.45 : 0),
                                        style: StrokeStyle(lineWidth: 2.0 * scale, lineCap: .round))
                                .frame(width: CGFloat(18 + i * 4) * scale, height: 2 * scale)
                                .rotationEffect(.degrees(Double(i) * 60))
                                .offset(y: 44 * scale)
                                .scaleEffect(shardsLaunched ? 1.0 : 0.3)
                                .animation(
                                    .easeOut(duration: 0.2).delay(Double(i) * 0.02),
                                    value: shardsLaunched
                                )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(20)
        }
        .frame(height: 190)
        .onAppear {
            if !hasPlayedOnce {
                hasPlayedOnce = true
                playBreakSequence()
            }
        }
        .onChange(of: pulseID) { _, _ in
            playBreakSequence()
        }
        .accessibilityLabel("Glass breaking visualization")
    }

    private func playBreakSequence() {
        let now = Date()
        guard now.timeIntervalSince(Self.lastShatterTime) > Self.cooldownSeconds else { return }
        Self.lastShatterTime = now

        let token = UUID()
        playToken = token

        glassTilt = 0; glassFall = 0; glassVisible = true
        impactFlash = false; shardsLaunched = false; shakeY = 0

        // Tip
        withAnimation(.easeIn(duration: tipDuration * 0.6)) { glassTilt = 0.3 }
        DispatchQueue.main.asyncAfter(deadline: .now() + tipDuration * 0.5) {
            guard playToken == token else { return }
            withAnimation(.easeIn(duration: tipDuration * 0.5)) { glassTilt = 1.0 }
        }

        // Fall
        DispatchQueue.main.asyncAfter(deadline: .now() + fallDelay) {
            guard playToken == token else { return }
            glassFall = 1.0
        }

        // Impact
        DispatchQueue.main.asyncAfter(deadline: .now() + impactDelay) {
            guard playToken == token else { return }
            glassVisible = false
            impactFlash = true
            shardsLaunched = true
            shakeY = -shakeAmount
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + impactDelay + 0.04) {
            guard playToken == token else { return }
            withAnimation(.easeOut(duration: 0.08)) { shakeY = shakeAmount * 0.4 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + impactDelay + 0.10) {
            guard playToken == token else { return }
            withAnimation(.easeOut(duration: 0.06)) { shakeY = 0 }
            impactFlash = false
        }

        // Reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard playToken == token else { return }
            withAnimation(.easeIn(duration: 0.3)) { shardsLaunched = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            guard playToken == token else { return }
            glassTilt = 0; glassFall = 0
            withAnimation(.easeOut(duration: 0.25)) { glassVisible = true }
        }
    }

    // MARK: - Shard Helpers

    private func shardFinalPos(_ i: Int) -> CGPoint {
        let p: [CGPoint] = [
            CGPoint(x: -45, y: 20), CGPoint(x: -28, y: 10), CGPoint(x: -15, y: -15),
            CGPoint(x: -8, y: 30), CGPoint(x: 5, y: -20), CGPoint(x: 12, y: 25),
            CGPoint(x: 22, y: -10), CGPoint(x: 35, y: 15), CGPoint(x: 48, y: 28),
            CGPoint(x: -35, y: 35),
        ]
        return p[i % p.count]
    }

    private func shardSize(_ i: Int) -> (w: CGFloat, h: CGFloat) {
        let s: [(CGFloat, CGFloat)] = [
            (10,12),(7,9),(8,6),(5,8),(9,11),(6,7),(8,10),(7,5),(6,9),(5,6)
        ]
        return s[i % s.count]
    }

    private func shardOpacity(_ i: Int) -> CGFloat {
        [0.7, 0.5, 0.6, 0.45, 0.65, 0.5, 0.55, 0.6, 0.4, 0.5][i % 10]
    }

    private func dustOffset(_ i: Int) -> CGPoint {
        let o: [CGPoint] = [
            CGPoint(x:-20,y:30),CGPoint(x:-10,y:20),CGPoint(x:0,y:25),
            CGPoint(x:12,y:22),CGPoint(x:25,y:32),CGPoint(x:-5,y:35)
        ]
        return o[i % o.count]
    }

    private func splashOffset(_ i: Int) -> CGPoint {
        let o: [CGPoint] = [
            CGPoint(x: -30, y: -25),
            CGPoint(x: -15, y: -35),
            CGPoint(x: 5, y: -30),
            CGPoint(x: 20, y: -20),
            CGPoint(x: 35, y: -28),
        ]
        return o[i % o.count]
    }
}

// MARK: - Shapes

private struct DrinkingGlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tl = CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY)
        let tr = CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.minY)
        let bl = CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY - rect.height * 0.12)
        let br = CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.maxY - rect.height * 0.12)
        let basL = CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY)
        let basR = CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.maxY)

        p.move(to: tl); p.addLine(to: tr)
        p.addQuadCurve(to: br, control: CGPoint(x: rect.maxX - rect.width * 0.13, y: rect.midY))
        p.addLine(to: basR); p.addLine(to: basL); p.addLine(to: bl)
        p.addQuadCurve(to: tl, control: CGPoint(x: rect.minX + rect.width * 0.13, y: rect.midY))
        return p
    }
}

private struct DrinkingGlassFill: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tl = CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY)
        let tr = CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.minY)
        let bl = CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY - rect.height * 0.12)
        let br = CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.maxY - rect.height * 0.12)
        let basL = CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY)
        let basR = CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.maxY)

        p.move(to: tl); p.addLine(to: tr)
        p.addQuadCurve(to: br, control: CGPoint(x: rect.maxX - rect.width * 0.13, y: rect.midY))
        p.addLine(to: basR); p.addLine(to: basL); p.addLine(to: bl)
        p.addQuadCurve(to: tl, control: CGPoint(x: rect.minX + rect.width * 0.13, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

private struct GlassShardShape: Shape {
    let variant: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch variant % 5 {
        case 0:
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.8)); p.closeSubpath()
        case 1:
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.midX * 0.5, y: rect.maxY)); p.closeSubpath()
        case 2:
            p.move(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.3))
            p.addLine(to: CGPoint(x: rect.maxX * 0.8, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.6)); p.closeSubpath()
        case 3:
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX + rect.width * 0.15, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.midX - rect.width * 0.15, y: rect.maxY)); p.closeSubpath()
        default:
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY)); p.closeSubpath()
        }
        return p
    }
}

// MARK: - Splash Droplet

private struct SplashDroplet: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                       control: CGPoint(x: rect.minX - rect.width * 0.2, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                       control: CGPoint(x: rect.maxX + rect.width * 0.2, y: rect.midY))
        return p
    }
}

// MARK: - Floor Crack Lines

private struct FloorCrackLines: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        let ends: [(CGFloat, CGFloat)] = [
            (-0.5, -0.3), (-0.3, 0.4), (0.0, -0.5),
            (0.35, 0.3), (0.5, -0.2)
        ]
        for (dx, dy) in ends {
            p.move(to: center)
            p.addLine(to: CGPoint(x: center.x + rect.width * dx,
                                  y: center.y + rect.height * dy))
        }
        return p
    }
}

// MARK: - Impact Line

private struct ImpactLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX - rect.width * 0.15, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.move(to: CGPoint(x: rect.midX + rect.width * 0.15, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
