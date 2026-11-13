import CoreGraphics
import Foundation

// Hand-drawn-looking input for tests and the render tool: shapes with tremor, wobble, hooks and overshoot, generated
// from a fixed seed so every run is the same.
public enum SampleStrokes {
    public struct Sample {
        public let name: String
        public let points: [CGPoint]
    }

    public static func all(seed: UInt64 = 7) -> [Sample] {
        var random = SeededRandom(seed: seed)
        return [
            Sample(name: "underline", points: underline(&random)),
            Sample(name: "circle", points: circle(&random)),
            Sample(name: "oval", points: oval(&random)),
            Sample(name: "check", points: check(&random)),
            Sample(name: "wave", points: wave(&random)),
            Sample(name: "box", points: box(&random)),
            Sample(name: "tick", points: tick(&random)),
            Sample(name: "u-turn", points: uTurn(&random)),
        ]
    }

    // A slightly sagging underline with a release flick at the end.
    static func underline(_ random: inout SeededRandom) -> [CGPoint] {
        var points = path(count: 140, random: &random) { t in
            CGPoint(x: 20 + 380 * t, y: 60 + 6 * sin(t * .pi) + 3 * sin(t * 9))
        }
        let end = points.last!
        points += [CGPoint(x: end.x + 3, y: end.y - 4), CGPoint(x: end.x + 4, y: end.y - 9)]
        return points
    }

    // A circle drawn around something, lumpy, starting at the top and overshooting past the start.
    static func circle(_ random: inout SeededRandom) -> [CGPoint] {
        path(count: 220, random: &random) { t in
            let angle = -.pi / 2 + t * (2 * .pi + 0.9)
            let radius = 110 + 9 * sin(3 * angle + 1) + 5 * sin(5 * angle)
            return CGPoint(x: 200 + radius * cos(angle) * 1.15, y: 140 + radius * sin(angle))
        }
    }

    // A wide oval that doesn't quite close, ending a little short of its start.
    static func oval(_ random: inout SeededRandom) -> [CGPoint] {
        path(count: 200, random: &random) { t in
            let angle = .pi + t * (2 * .pi - 0.35)
            let wobble = 1 + 0.06 * sin(4 * angle)
            return CGPoint(x: 220 + 190 * cos(angle) * wobble, y: 90 + 60 * sin(angle) * wobble + 10 * t)
        }
    }

    static func check(_ random: inout SeededRandom) -> [CGPoint] {
        let a = CGPoint(x: 40, y: 80), b = CGPoint(x: 90, y: 135), c = CGPoint(x: 210, y: 20)
        return path(count: 90, random: &random) { t in
            t < 0.3 ? lerp(a, b, t / 0.3) : lerp(b, c, (t - 0.3) / 0.7)
        }
    }

    static func wave(_ random: inout SeededRandom) -> [CGPoint] {
        path(count: 160, random: &random) { t in
            CGPoint(x: 20 + 380 * t, y: 80 + 45 * sin(t * 2 * .pi * 1.5))
        }
    }

    // A rough rectangle drawn freehand, closed by hand.
    static func box(_ random: inout SeededRandom) -> [CGPoint] {
        let corners = [CGPoint(x: 40, y: 30), CGPoint(x: 360, y: 36), CGPoint(x: 352, y: 170), CGPoint(x: 46, y: 162),
                       CGPoint(x: 48, y: 40)]
        return path(count: 220, random: &random) { t in
            let segment = min(Int(t * 4), 3)
            return lerp(corners[segment], corners[segment + 1], t * 4 - CGFloat(segment))
        }
    }

    static func tick(_ random: inout SeededRandom) -> [CGPoint] {
        let a = CGPoint(x: 20, y: 30), b = CGPoint(x: 32, y: 44), c = CGPoint(x: 56, y: 12)
        return path(count: 30, random: &random) { t in
            t < 0.35 ? lerp(a, b, t / 0.35) : lerp(b, c, (t - 0.35) / 0.65)
        }
    }

    // A narrow U whose ends come close together but which isn't a loop.
    static func uTurn(_ random: inout SeededRandom) -> [CGPoint] {
        path(count: 160, random: &random) { t in
            if t < 0.35 { return CGPoint(x: 60, y: 30 + 200 * (t / 0.35)) }
            if t > 0.65 { return CGPoint(x: 100, y: 230 - 200 * ((t - 0.65) / 0.35)) }
            let turn = (t - 0.35) / 0.3 * .pi
            return CGPoint(x: 80 - 20 * cos(turn), y: 230 + 20 * sin(turn))
        }
    }

    // Samples a shape the way a pointer reports it: uneven speed, tremor and a slow drift.
    static func path(count: Int, random: inout SeededRandom, shape: (CGFloat) -> CGPoint) -> [CGPoint] {
        let driftPhase = random.next() * 2 * .pi
        return (0..<count).map { index in
            var t = CGFloat(index) / CGFloat(count - 1)
            t = min(max(t + (random.next() - 0.5) * 0.004, 0), 1)
            let point = shape(t)
            let drift = 2.5 * sin(t * 11 + driftPhase)
            return CGPoint(
                x: point.x + drift + (random.next() - 0.5) * 3.2,
                y: point.y - drift + (random.next() - 0.5) * 3.2
            )
        }
    }

    static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}
