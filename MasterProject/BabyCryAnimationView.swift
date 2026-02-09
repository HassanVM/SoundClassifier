// BabyCryAnimationView.swift
// UPDATE: Replace entire file

import SwiftUI

struct BabyCryAnimationView: View {
    let pulseID: Int
    var intensity: IntensityLevel = .urgent

    @State private var playToken = UUID()
    @State private var shakeX: CGFloat = 0
    @State private var sobOn = false
    @State private var tearsOn = false
    @State private var sweatOn = false

    // Intensity-driven constants
    private var repeats: Int { intensity == .urgent ? 7 : 2 }
    private var cycle: TimeInterval { intensity == .urgent ? 0.28 : 0.55 }
    private var shakeAmount: CGFloat { intensity == .urgent ? 5 : 0.5 }
    private var showSweat: Bool { intensity == .urgent }
    private var showTears: Bool { intensity == .urgent }
    private var mouthScale: CGFloat { intensity == .urgent ? 0.40 : 0.20 }
    private var mouthHeightScale: CGFloat { intensity == .urgent ? 0.28 : 0.12 }

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
                    sweatOn: sweatOn,
                    mouthWidthScale: mouthScale,
                    mouthHeightScale: mouthHeightScale
                )
                .offset(x: shakeX)
                .animation(.easeOut(duration: 0.06), value: shakeX)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(22)
        }
        .frame(height: 190)
        .onChange(of: pulseID) { _, _ in playCrySequence() }
        .accessibilityLabel("Baby crying")
    }

    private func playCrySequence() {
        let token = UUID()
        playToken = token

        shakeX = 0; sobOn = false; tearsOn = false; sweatOn = false

        for i in 0..<repeats {
            let t = TimeInterval(i) * cycle

            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                guard playToken == token else { return }
                sobOn = true
                tearsOn = showTears
                sweatOn = showSweat
                shakeX = (i % 2 == 0) ? -shakeAmount : shakeAmount
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + t + cycle * 0.53) {
                guard playToken == token else { return }
                sobOn = false
                shakeX = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + t + cycle * 0.82) {
                guard playToken == token else { return }
                tearsOn = false
                sweatOn = false
            }
        }

        let total = TimeInterval(repeats) * cycle
        DispatchQueue.main.asyncAfter(deadline: .now() + total + 0.6) {
            guard playToken == token else { return }
            sobOn = false; tearsOn = false; sweatOn = false; shakeX = 0
        }
    }
}

// MARK: - Baby Face Icon

private struct BabyFaceIcon: View {
    let base: CGFloat
    let sobOn: Bool
    let tearsOn: Bool
    let sweatOn: Bool
    var mouthWidthScale: CGFloat = 0.36
    var mouthHeightScale: CGFloat = 0.24

    var body: some View {
        let face = base * 0.92
        let stroke = max(2, base * 0.045)

        ZStack {
            Circle()
                .stroke(.primary.opacity(0.88), lineWidth: stroke)
                .frame(width: face, height: face)

            Circle()
                .stroke(.primary.opacity(0.88), lineWidth: stroke)
                .frame(width: face * 0.20, height: face * 0.20)
                .offset(x: -face * 0.56, y: 0)
            Circle()
                .stroke(.primary.opacity(0.88), lineWidth: stroke)
                .frame(width: face * 0.20, height: face * 0.20)
                .offset(x: face * 0.56, y: 0)

            HairCurl()
                .stroke(.primary.opacity(0.88),
                        style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round))
                .frame(width: face * 0.28, height: face * 0.28)
                .offset(y: -face * 0.52)

            EyeSquints()
                .stroke(.primary.opacity(0.88),
                        style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .frame(width: face * 0.46, height: face * 0.20)
                .offset(y: -face * 0.10)

            MouthOval()
                .stroke(.primary.opacity(0.88),
                        style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round))
                .frame(width: face * (sobOn ? mouthWidthScale : mouthWidthScale * 0.78),
                       height: face * (sobOn ? mouthHeightScale : mouthHeightScale * 0.75))
                .offset(y: face * 0.18)
                .animation(.easeInOut(duration: 0.12), value: sobOn)

            // Sweat drops (only for urgent)
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

            // Tears
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
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.midY + rect.height * 0.18))
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.midY - rect.height * 0.18))
        p.move(to: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.26, y: rect.midY + rect.height * 0.18))
        p.move(to: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.26, y: rect.midY - rect.height * 0.18))
        return p
    }
}

private struct MouthOval: Shape {
    func path(in rect: CGRect) -> Path { var p = Path(); p.addEllipse(in: rect); return p }
}

private struct TearDrop: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let top = CGPoint(x: rect.midX, y: rect.minY)
        let left = CGPoint(x: rect.minX, y: rect.midY)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY)
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
        p.addQuadCurve(to: bottom, control: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                       control: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.maxY))
        p.addQuadCurve(to: top, control: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25))
        return p
    }
}
