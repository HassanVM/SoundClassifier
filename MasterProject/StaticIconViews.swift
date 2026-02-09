// StaticIconViews.swift
// Static action-based icons for Condition B
// Each category has a routine and urgent variant drawn to match
// frozen keyframes from the Condition C animations.

import SwiftUI

// MARK: - Master Static Icon Dispatcher

struct StaticSoundIcon: View {
    let category: SoundCategory
    let intensity: IntensityLevel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                )

            iconContent
        }
        .frame(height: 190)
        .accessibilityLabel("\(category.displayName) — \(intensity.displayName)")
    }

    @ViewBuilder
    private var iconContent: some View {
        switch category {
        case .knocking:
            StaticKnockIcon(intensity: intensity)
        case .dogBarking:
            StaticDogBarkIcon(intensity: intensity)
        case .babyCrying:
            StaticBabyCryIcon(intensity: intensity)
        case .alarm:
            StaticAlarmIcon(intensity: intensity)
        case .glassBreaking:
            StaticGlassBreakIcon(intensity: intensity)
        case .coughing:
            StaticCoughIcon(intensity: intensity)
        }
    }
}

// MARK: - Knocking Static Icon
// Routine: person standing with arm partially raised toward door, small impact circle
// Urgent: person with arm fully extended hitting door, door slightly shifted, larger double ripple

private struct StaticKnockIcon: View {
    let intensity: IntensityLevel
    private var isUrgent: Bool { intensity == .urgent }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let scale = size / 180

            ZStack {
                // Door
                StaticDoorShape()
                    .fill(.primary.opacity(0.92), style: FillStyle(eoFill: true))
                    .frame(width: 70 * scale, height: 130 * scale)
                    .offset(x: 46 * scale + (isUrgent ? 3 * scale : 0))

                // Person with arm position based on intensity
                StaticPersonKnocking(armExtension: isUrgent ? 1.0 : 0.55)
                    .fill(.primary.opacity(0.92))
                    .frame(width: 120 * scale, height: 150 * scale)
                    .offset(x: -18 * scale, y: 8 * scale)

                // Impact ripple(s)
                Circle()
                    .stroke(.primary.opacity(isUrgent ? 0.50 : 0.20),
                            lineWidth: (isUrgent ? 2.5 : 1.5) * scale)
                    .frame(width: (isUrgent ? 42 : 28) * scale,
                           height: (isUrgent ? 42 : 28) * scale)
                    .offset(x: 64 * scale, y: -10 * scale)

                // Second outer ripple — urgent only
                if isUrgent {
                    Circle()
                        .stroke(.primary.opacity(0.25), lineWidth: 1.5 * scale)
                        .frame(width: 62 * scale, height: 62 * scale)
                        .offset(x: 64 * scale, y: -10 * scale)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
    }
}

private struct StaticDoorShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let outer = rect
        let inner = rect.insetBy(dx: rect.width * 0.12, dy: rect.height * 0.07)
        let corner = min(rect.width, rect.height) * 0.14

        p.addRoundedRect(in: outer, cornerSize: CGSize(width: corner, height: corner))
        p.addRoundedRect(in: inner, cornerSize: CGSize(width: corner * 0.7, height: corner * 0.7))

        let handleWidth = rect.width * 0.12
        let handleHeight = rect.height * 0.06
        let handleX = rect.maxX - handleWidth * 1.6
        let handleY = rect.midY - handleHeight / 2
        p.addRoundedRect(in: CGRect(x: handleX, y: handleY, width: handleWidth, height: handleHeight),
                         cornerSize: CGSize(width: handleHeight / 2, height: handleHeight / 2))
        return p
    }
}

private struct StaticPersonKnocking: Shape {
    let armExtension: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }

        // Head
        let headCenter = pt(0.32, 0.18)
        let headR = rect.width * 0.11
        p.addEllipse(in: CGRect(x: headCenter.x - headR, y: headCenter.y - headR,
                                width: headR * 2, height: headR * 2))

        // Torso
        p.addRoundedRect(in: CGRect(x: rect.minX + rect.width * 0.18,
                                     y: rect.minY + rect.height * 0.30,
                                     width: rect.width * 0.30,
                                     height: rect.height * 0.34),
                         cornerSize: CGSize(width: rect.width * 0.1, height: rect.width * 0.1))

        // Legs
        p.addRoundedRect(in: CGRect(x: rect.minX + rect.width * 0.20,
                                     y: rect.minY + rect.height * 0.66,
                                     width: rect.width * 0.14, height: rect.height * 0.30),
                         cornerSize: CGSize(width: rect.width * 0.08, height: rect.width * 0.08))
        p.addRoundedRect(in: CGRect(x: rect.minX + rect.width * 0.32,
                                     y: rect.minY + rect.height * 0.66,
                                     width: rect.width * 0.14, height: rect.height * 0.30),
                         cornerSize: CGSize(width: rect.width * 0.08, height: rect.width * 0.08))

        // Right arm
        let shoulder = pt(0.44, 0.38)
        let elbow = pt(0.58, 0.46)
        let hit = min(armExtension, 1.0)
        let wristX = lerp(0.70, 0.82, hit)
        let wristY = lerp(0.48, 0.42, hit)
        let wrist = pt(wristX, wristY)

        p.addPath(line(from: shoulder, to: elbow, width: rect.width * 0.09))
        p.addPath(line(from: elbow, to: wrist, width: rect.width * 0.09))
        let handR = rect.width * 0.045
        p.addEllipse(in: CGRect(x: wrist.x - handR, y: wrist.y - handR,
                                width: handR * 2, height: handR * 2))

        return p
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
    private func line(from a: CGPoint, to b: CGPoint, width: CGFloat) -> Path {
        var p = Path(); p.move(to: a); p.addLine(to: b)
        return p.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round))
    }
}


// MARK: - Dog Bark Static Icon
// Uses bundled images: "dog_bark_routine" and "dog_bark_urgent" in Assets.xcassets

private struct StaticDogBarkIcon: View {
    let intensity: IntensityLevel

    var body: some View {
        Image(intensity == .urgent ? "dog_bark_urgent" : "dog_bark_routine")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(20)
    }
}


// MARK: - Baby Cry Static Icon
// Routine: baby face with squinted eyes, small oval mouth, no tears
// Urgent: baby face with wide open mouth, tears, sweat drops

private struct StaticBabyCryIcon: View {
    let intensity: IntensityLevel
    private var isUrgent: Bool { intensity == .urgent }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let base: CGFloat = min(120, h * 0.78)
            let face = base * 0.92
            let stroke = max(2, base * 0.045)

            ZStack {
                // Head circle
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
                StaticHairCurl()
                    .stroke(.primary.opacity(0.88),
                            style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round))
                    .frame(width: face * 0.28, height: face * 0.28)
                    .offset(y: -face * 0.52)

                // Eyes — squinted chevrons
                StaticEyeSquints()
                    .stroke(.primary.opacity(0.88),
                            style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .frame(width: face * 0.46, height: face * 0.20)
                    .offset(y: -face * 0.10)

                // Mouth — small oval for routine, wide open for urgent
                Ellipse()
                    .stroke(.primary.opacity(0.88),
                            style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round))
                    .frame(width: face * (isUrgent ? 0.40 : 0.18),
                           height: face * (isUrgent ? 0.28 : 0.10))
                    .offset(y: face * 0.18)

                // Tears — urgent only
                if isUrgent {
                    StaticTearDrop()
                        .fill(Color.blue.opacity(0.85))
                        .frame(width: face * 0.10, height: face * 0.16)
                        .offset(x: -face * 0.23, y: face * 0.08)
                    StaticTearDrop()
                        .fill(Color.blue.opacity(0.85))
                        .frame(width: face * 0.10, height: face * 0.16)
                        .offset(x: face * 0.23, y: face * 0.08)
                }

                // Sweat drops — urgent only
                if isUrgent {
                    StaticSweatDrop()
                        .fill(.primary.opacity(0.60))
                        .frame(width: face * 0.08, height: face * 0.11)
                        .offset(x: -face * 0.38, y: -face * 0.36)
                    StaticSweatDrop()
                        .fill(.primary.opacity(0.60))
                        .frame(width: face * 0.07, height: face * 0.10)
                        .offset(x: face * 0.40, y: -face * 0.34)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(22)
    }
}

private struct StaticHairCurl: Shape {
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

private struct StaticEyeSquints: Shape {
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

private struct StaticTearDrop: Shape {
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

private struct StaticSweatDrop: Shape {
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


// MARK: - Alarm Static Icon
// Uses bundled images: "alarm_routine" and "alarm_urgent" in Assets.xcassets

private struct StaticAlarmIcon: View {
    let intensity: IntensityLevel

    var body: some View {
        Image(intensity == .urgent ? "alarm_urgent" : "alarm_routine")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(20)
    }
}


// MARK: - Glass Breaking Static Icon
// Routine: few small shards scattered, floor line, no impact lines
// Urgent: many shards spread wider, floor crack lines, impact star at contact point

private struct StaticGlassBreakIcon: View {
    let intensity: IntensityLevel
    private var isUrgent: Bool { intensity == .urgent }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let base: CGFloat = min(120, h * 0.78)
            let scale = base / 120

            ZStack {
                // Floor line
                Rectangle()
                    .fill(.primary.opacity(0.25))
                    .frame(width: 140 * scale, height: 1.5 * scale)
                    .offset(y: 48 * scale)

                // Shards
                let shardCount = isUrgent ? 10 : 5
                ForEach(0..<shardCount, id: \.self) { i in
                    StaticShardShape(variant: i)
                        .fill(.primary.opacity(shardOpacity(i)))
                        .frame(width: CGFloat(shardSize(i).w) * scale,
                               height: CGFloat(shardSize(i).h) * scale)
                        .offset(
                            x: shardPos(i).x * (isUrgent ? 1.4 : 0.8) * scale,
                            y: shardPos(i).y * (isUrgent ? 1.0 : 0.8) * scale
                        )
                        .rotationEffect(.degrees(Double(i * 36 + 10)))
                }

                // Dust dots
                let dustCount = isUrgent ? 6 : 3
                ForEach(0..<dustCount, id: \.self) { i in
                    Circle()
                        .fill(.primary.opacity(0.35))
                        .frame(width: 2.5 * scale, height: 2.5 * scale)
                        .offset(
                            x: dustPos(i).x * scale,
                            y: dustPos(i).y * scale
                        )
                }

                // Floor crack lines — urgent only
                if isUrgent {
                    StaticFloorCracks()
                        .stroke(.primary.opacity(0.3),
                                style: StrokeStyle(lineWidth: 1.2 * scale, lineCap: .round))
                        .frame(width: 80 * scale, height: 12 * scale)
                        .offset(y: 50 * scale)

                    // Impact radiating lines
                    ForEach(0..<6, id: \.self) { i in
                        StaticImpactLine()
                            .stroke(.primary.opacity(0.45),
                                    style: StrokeStyle(lineWidth: 2.0 * scale, lineCap: .round))
                            .frame(width: CGFloat(18 + i * 4) * scale, height: 2 * scale)
                            .rotationEffect(.degrees(Double(i) * 60))
                            .offset(y: 44 * scale)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
    }

    private func shardPos(_ i: Int) -> CGPoint {
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

    private func dustPos(_ i: Int) -> CGPoint {
        let o: [CGPoint] = [
            CGPoint(x: -20, y: 30), CGPoint(x: 0, y: 25),
            CGPoint(x: 12, y: 22), CGPoint(x: 25, y: 32),
            CGPoint(x: -10, y: 35), CGPoint(x: -5, y: 28)
        ]
        return o[i % o.count]
    }
}

private struct StaticShardShape: Shape {
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

private struct StaticFloorCracks: Shape {
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

private struct StaticImpactLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX - rect.width * 0.15, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.move(to: CGPoint(x: rect.midX + rect.width * 0.15, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}


// MARK: - Coughing Static Icon
// Routine: person with hand to mouth, slight lean, small cloud puff
// Urgent: person leaning forward more, shoulders hunched, large cloud with speed lines

private struct StaticCoughIcon: View {
    let intensity: IntensityLevel
    private var isUrgent: Bool { intensity == .urgent }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let base: CGFloat = min(120, h * 0.78)
            let scale = base / 120

            ZStack {
                // Person shape — different lean amounts
                StaticCoughPersonShape(
                    leanProgress: isUrgent ? 0.85 : 0.30,
                    handProgress: 1.0,
                    shoulderProgress: isUrgent ? 0.85 : 0.20
                )
                .fill(.primary.opacity(0.92))
                .frame(width: 100 * scale, height: 150 * scale)
                .offset(x: -10 * scale)

                // Cloud puffs
                StaticCoughCloud(isUrgent: isUrgent, scale: scale)
                    .offset(x: 38 * scale, y: -28 * scale)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
    }
}

private struct StaticCoughCloud: View {
    let isUrgent: Bool
    let scale: CGFloat

    private var puffCount: Int { isUrgent ? 5 : 3 }
    private var maxSize: CGFloat { isUrgent ? 22 : 14 }
    private var spread: CGFloat { isUrgent ? 1.3 : 1.0 }

    private var puffData: [(dx: CGFloat, dy: CGFloat, size: CGFloat)] {
        let base: [(dx: CGFloat, dy: CGFloat, size: CGFloat)] = [
            (dx: 8, dy: -2, size: 0.55),
            (dx: 20, dy: -6, size: 0.75),
            (dx: 34, dy: -3, size: 1.00),
            (dx: 48, dy: -8, size: 0.85),
            (dx: 60, dy: -1, size: 0.60),
        ]
        return Array(base.prefix(puffCount))
    }

    var body: some View {
        ZStack {
            ForEach(0..<puffCount, id: \.self) { i in
                let data = puffData[i]
                let puffSize = maxSize * data.size * scale

                StaticCloudPuff()
                    .fill(.primary.opacity(isUrgent ? 0.28 : 0.18))
                    .frame(width: puffSize * 1.4, height: puffSize)
                    .offset(
                        x: data.dx * scale * spread,
                        y: data.dy * scale * spread
                    )
            }

            let lineCount = isUrgent ? 4 : 2
            ForEach(0..<lineCount, id: \.self) { i in
                Rectangle()
                    .fill(.primary.opacity(0.22))
                    .frame(width: CGFloat(10 + i * 5) * scale * (isUrgent ? 1.3 : 1.0),
                           height: 1.2 * scale)
                    .offset(
                        x: CGFloat(6 + i * 10) * scale * spread,
                        y: CGFloat(-4 + i * 4) * scale
                    )
            }

            if isUrgent {
                Ellipse()
                    .fill(.primary.opacity(0.08))
                    .frame(width: 50 * scale, height: 28 * scale)
                    .offset(x: 38 * scale * spread, y: -4 * scale)
            }
        }
    }
}

private struct StaticCloudPuff: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.addEllipse(in: CGRect(x: rect.minX, y: rect.minY + h * 0.15,
                                width: w * 0.50, height: h * 0.70))
        p.addEllipse(in: CGRect(x: rect.minX + w * 0.20, y: rect.minY,
                                width: w * 0.55, height: h))
        p.addEllipse(in: CGRect(x: rect.minX + w * 0.45, y: rect.minY + h * 0.10,
                                width: w * 0.55, height: h * 0.75))
        return p
    }
}

private struct StaticCoughPersonShape: Shape {
    let leanProgress: CGFloat
    let handProgress: CGFloat
    let shoulderProgress: CGFloat

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

        p.addRoundedRect(in: CGRect(x: rect.minX + rect.width * 0.30,
                                     y: rect.minY + rect.height * 0.62,
                                     width: rect.width * 0.12, height: rect.height * 0.34),
                         cornerSize: CGSize(width: rect.width * 0.06, height: rect.width * 0.06))
        p.addRoundedRect(in: CGRect(x: rect.minX + rect.width * 0.42,
                                     y: rect.minY + rect.height * 0.62,
                                     width: rect.width * 0.12, height: rect.height * 0.34),
                         cornerSize: CGSize(width: rect.width * 0.06, height: rect.width * 0.06))

        let shoulder = pt(0.52 + leanX * 0.3, 0.32 + shoulderLift)
        let elbow = CGPoint(x: lerp(pt(0.62, 0.48).x, pt(0.58 + leanX, 0.28 + leanY).x, handProgress),
                            y: lerp(pt(0.62, 0.48).y, pt(0.58 + leanX, 0.28 + leanY).y, handProgress))
        let hand = CGPoint(x: lerp(pt(0.65, 0.52).x, pt(0.48 + leanX, 0.18 + leanY).x, handProgress),
                           y: lerp(pt(0.65, 0.52).y, pt(0.48 + leanX, 0.18 + leanY).y, handProgress))

        p.addPath(line(from: shoulder, to: elbow, width: rect.width * 0.07))
        p.addPath(line(from: elbow, to: hand, width: rect.width * 0.07))
        let handR = rect.width * 0.04
        p.addEllipse(in: CGRect(x: hand.x - handR, y: hand.y - handR,
                                width: handR * 2, height: handR * 2))

        let lShoulder = pt(0.26 + leanX * 0.2, 0.32 + shoulderLift)
        let lElbow = pt(0.18, lerp(0.46, 0.40, leanProgress))
        let lHand = pt(lerp(0.16, 0.30, leanProgress), lerp(0.54, 0.44, leanProgress))
        p.addPath(line(from: lShoulder, to: lElbow, width: rect.width * 0.07))
        p.addPath(line(from: lElbow, to: lHand, width: rect.width * 0.07))
        p.addEllipse(in: CGRect(x: lHand.x - handR, y: lHand.y - handR,
                                width: handR * 2, height: handR * 2))

        return p
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
    private func line(from a: CGPoint, to b: CGPoint, width: CGFloat) -> Path {
        var p = Path(); p.move(to: a); p.addLine(to: b)
        return p.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round))
    }
}


// MARK: - Updated StaticIconCard (replaces the one in ContentView)

struct StaticIconCardV2: View {
    let display: AwarenessDisplayState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(display.category.displayName)
                    .font(.headline)
                Spacer()
                ConfidencePillPublic(bucket: display.confidenceBucket)
            }

            StaticSoundIcon(category: display.category, intensity: display.intensityLevel)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ConfidencePillPublic: View {
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
