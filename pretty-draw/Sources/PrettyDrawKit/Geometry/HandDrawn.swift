import CoreGraphics

// The hand-drawn style. Lines are marker ink: a touch thinner where the pen lands, tapering as it lifts, never quite even.
// Rectangles and arrows are sketched the way a quick hand draws them: sides bow a little and run past the corners, and
// an arrow's head is two flicks out from its tip. A loop carries on past where it started. The seed varies all of it
// from mark to mark, and draws a mark the same way every time.
//
// Each shape comes out as ink: paths to fill one after another.
enum HandDrawn {
    // Points along the ink are this far apart.
    static let spacing: CGFloat = 2
    // How many points of a line are filled together. Filling shapes that overlap takes time that grows with the square
    // of how many there are, so a long line is filled a few points at a time.
    static let runLength = 8
    // How far the ink's width wanders either way, as a fraction of the line width.
    static let swell: CGFloat = 0.1

    // MARK: Shapes

    static func stroke(_ points: [CGPoint], closed: Bool, width: CGFloat, seed: UInt64) -> [CGPath] {
        if closed {
            var random = SeededRandom(seed: seed)
            return ink(overlapping(points, width: width, random: &random), width: width, ends: (0.8, 0.5), seed: seed)
        }
        return ink(points, width: width, ends: (0.8, 0.55), seed: seed)
    }

    // Four strokes, one per side, going round from the top left.
    static func rectangle(_ rect: CGRect, width: CGFloat, seed: UInt64) -> [CGPath] {
        var random = SeededRandom(seed: seed)
        var sides: [CGPath] = []
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY),
        ]
        for side in 0..<4 {
            let line = sketchedSide(from: corners[side], to: corners[(side + 1) % 4], width: width, random: &random)
            sides += ink(line, width: width, ends: (0.85, 0.6), seed: seed &+ UInt64(side + 1))
        }
        return sides
    }

    // A gently bowed shaft, full right up to the tip, and an open head.
    static func arrow(from tail: CGPoint, to tip: CGPoint, width: CGFloat, seed: UInt64) -> [CGPath] {
        var random = SeededRandom(seed: seed)
        let length = GuidedStroke.distance(tail, tip)
        let across = normal(from: tail, to: tip)
        let bow = min(0.03 * length, 0.4 * width + 5) * random.next(in: 0.4...1) * random.sign()
        let control = offset(midpoint(tail, tip), across, 2 * bow)
        var arrow = ink(curve(tail, control, tip), width: width, ends: (0.75, 1), seed: seed)
        guard length > 0.5 else { return arrow }

        // Each flick starts at the tip and leaves back along the shaft's last stretch.
        let back = GuidedStroke.direction(from: tip, to: control)
        let head = headLength(width: width, length: length)
        for side: CGFloat in [-1, 1] {
            let angle = side * random.next(in: 30...36) * .pi / 180
            let direction = CGVector(
                dx: back.dx * cos(angle) - back.dy * sin(angle),
                dy: back.dx * sin(angle) + back.dy * cos(angle)
            )
            let end = offset(tip, direction, head * random.next(in: 0.85...1.05))
            let flick = 0.06 * head * random.next(in: -1...1)
            let bend = offset(midpoint(tip, end), normal(from: tip, to: end), 2 * flick)
            arrow += ink(curve(tip, bend, end), width: width, ends: (1, 0.55), seed: seed &+ UInt64(side + 2))
        }
        return arrow
    }

    static func headLength(width: CGFloat, length: CGFloat) -> CGFloat {
        min(1.8 * width + 16, 0.5 * length)
    }

    // How far each shape's ink can reach beyond its points, its rectangle, or the box between an arrow's ends. The
    // canvas redraws within these, so they cover the most the random choices above can add up to.
    static func strokeReach(width: CGFloat) -> CGFloat {
        // The loop's drift.
        inkRadius(width: width) + 0.5 * width + 3
    }

    static func rectangleReach(width: CGFloat) -> CGFloat {
        // A side's slip and bow, which are more than its overshoot.
        inkRadius(width: width) + 0.5 * width + 4.5
    }

    static func arrowReach(width: CGFloat) -> CGFloat {
        // The longest flick and its bend, which are more than the shaft's bow.
        inkRadius(width: width) + 1.06 * 1.05 * (1.8 * width + 16)
    }

    // The farthest the ink gets from its centerline.
    static func inkRadius(width: CGFloat) -> CGFloat {
        (1 + swell) * width / 2
    }

    // MARK: Ink

    // Marker ink along a centerline. `ends` is the fraction of the width left where the pen lands and where it lifts.
    //
    // The ink is a circle at every point joined by a four-sided band along every step, all turning the same way, so
    // filling them with the nonzero rule covers their union with no seams or gaps however tightly the line turns. It
    // comes as one path for every `runLength` points, each with its circles and the bands that follow them.
    static func ink(
        _ centerline: [CGPoint], width: CGFloat, ends: (start: CGFloat, end: CGFloat), seed: UInt64
    ) -> [CGPath] {
        let points = GuidedStroke.resample(centerline, spacing: spacing)
        guard let first = points.first else { return [] }
        guard points.count > 1 else {
            let dot = CGMutablePath()
            addCircle(to: dot, center: first, radius: width / 2)
            return [dot]
        }

        var travelled: [CGFloat] = [0]
        for (a, b) in zip(points, points.dropFirst()) {
            travelled.append(travelled.last! + GuidedStroke.distance(a, b))
        }
        let total = travelled.last!
        let landing = min(2 * width + 6, 0.3 * total)
        let lifting = min(3 * width + 10, 0.4 * total)
        let wavelength = 10 * width + 100
        let swelling = Swelling(seed: seed)
        let radii = travelled.map { distance -> CGFloat in
            var factor: CGFloat = 1
            // Quickest right at the ends, so they round off like a pen's and level out without a corner.
            if distance < landing {
                factor *= ends.start + (1 - ends.start) * easeOut(distance / landing)
            }
            if distance > total - lifting {
                factor *= ends.end + (1 - ends.end) * easeOut((total - distance) / lifting)
            }
            factor *= 1 + swell * swelling(distance / wavelength)
            return width / 2 * factor
        }

        return stride(from: 0, to: points.count, by: runLength).map { start in
            let run = CGMutablePath()
            for index in start..<min(start + runLength, points.count) {
                addCircle(to: run, center: points[index], radius: radii[index])
                guard index + 1 < points.count else { continue }
                let a = points[index], b = points[index + 1]
                guard GuidedStroke.distance(a, b) > 0.01 else { continue }
                // Pointing right of the direction of travel, which keeps every band turning the way the circles do.
                let side = normal(from: b, to: a)
                run.move(to: offset(a, side, radii[index]))
                run.addLine(to: offset(b, side, radii[index + 1]))
                run.addLine(to: offset(b, side, -radii[index + 1]))
                run.addLine(to: offset(a, side, -radii[index]))
                run.closeSubpath()
            }
            return run
        }
    }

    // A circle from four Bézier quarters, turning from the x axis toward the y axis like the bands in `ink`.
    static func addCircle(to path: CGMutablePath, center c: CGPoint, radius r: CGFloat) {
        let k = 0.5523 * r
        path.move(to: CGPoint(x: c.x + r, y: c.y))
        path.addCurve(
            to: CGPoint(x: c.x, y: c.y + r), control1: CGPoint(x: c.x + r, y: c.y + k), control2: CGPoint(x: c.x + k, y: c.y + r)
        )
        path.addCurve(
            to: CGPoint(x: c.x - r, y: c.y), control1: CGPoint(x: c.x - k, y: c.y + r), control2: CGPoint(x: c.x - r, y: c.y + k)
        )
        path.addCurve(
            to: CGPoint(x: c.x, y: c.y - r), control1: CGPoint(x: c.x - r, y: c.y - k), control2: CGPoint(x: c.x - k, y: c.y - r)
        )
        path.addCurve(
            to: CGPoint(x: c.x + r, y: c.y), control1: CGPoint(x: c.x + k, y: c.y - r), control2: CGPoint(x: c.x + r, y: c.y - k)
        )
        path.closeSubpath()
    }

    // MARK: Sketching

    // One side of a rectangle: bowed a little, its ends a little off the corners, starting a touch before the first
    // corner and running on past the second, so neighbouring sides cross.
    static func sketchedSide(from start: CGPoint, to end: CGPoint, width: CGFloat, random: inout SeededRandom) -> [CGPoint] {
        let length = GuidedStroke.distance(start, end)
        let along = GuidedStroke.direction(from: start, to: end)
        let across = normal(from: start, to: end)
        let overshoot = min(0.4 * width + 4, 0.15 * length)
        let slip = min(0.2 * width + 1.5, 0.05 * length)
        let bow = min(0.012 * length + 1, 0.3 * width + 3) * random.next(in: 0.3...1) * random.sign()
        var a = offset(start, along, -overshoot * random.next(in: 0...0.5))
        var b = offset(end, along, overshoot * random.next(in: 0.4...1))
        a = offset(a, across, slip * random.next(in: -1...1))
        b = offset(b, across, slip * random.next(in: -1...1))
        return curve(a, offset(midpoint(a, b), across, 2 * bow), b)
    }

    // A loop drawn by hand doesn't close exactly: the pen carries on past where it started, drifting off the line.
    static func overlapping(_ loop: [CGPoint], width: CGFloat, random: inout SeededRandom) -> [CGPoint] {
        let points = GuidedStroke.resample(loop + [loop[0]], spacing: spacing)
        let overlap = min(0.12 * GuidedStroke.length(points), 2 * width + 24)
        let drift = min(0.5 * width + 3, 0.05 * GuidedStroke.diagonal(of: points)) * random.sign()
        let center = CGPoint(
            x: points.map(\.x).reduce(0, +) / CGFloat(points.count),
            y: points.map(\.y).reduce(0, +) / CGFloat(points.count)
        )
        var extended = points
        var travelled: CGFloat = 0
        for (a, b) in zip(points, points.dropFirst()) {
            travelled += GuidedStroke.distance(a, b)
            guard travelled <= overlap else { break }
            extended.append(offset(b, GuidedStroke.direction(from: center, to: b), drift * travelled / overlap))
        }
        return extended
    }

    // MARK: Helpers

    // A quadratic curve, as points `spacing` apart or closer.
    static func curve(_ start: CGPoint, _ control: CGPoint, _ end: CGPoint) -> [CGPoint] {
        let reach = GuidedStroke.distance(start, control) + GuidedStroke.distance(control, end)
        let count = max(Int((reach / spacing).rounded(.up)), 1)
        return (0...count).map { step in
            let t = CGFloat(step) / CGFloat(count)
            let a = (1 - t) * (1 - t), b = 2 * t * (1 - t), c = t * t
            return CGPoint(x: a * start.x + b * control.x + c * end.x, y: a * start.y + b * control.y + c * end.y)
        }
    }

    // How the pen's pressure wanders along a line: smooth, in -1...1, rising and falling about once per unit. Two waves
    // with unrelated lengths and seeded phases, so the pattern doesn't visibly repeat.
    struct Swelling {
        let phases: (CGFloat, CGFloat)
        let ratio: CGFloat

        init(seed: UInt64) {
            var random = SeededRandom(seed: seed)
            phases = (random.next() * 2 * .pi, random.next() * 2 * .pi)
            ratio = random.next(in: 1.7...2.3)
        }

        func callAsFunction(_ x: CGFloat) -> CGFloat {
            0.6 * sin(2 * .pi * x + phases.0) + 0.4 * sin(2 * .pi * ratio * x + phases.1)
        }
    }

    static func easeOut(_ t: CGFloat) -> CGFloat {
        let t = min(max(t, 0), 1)
        return t * (2 - t)
    }

    // The unit vector a quarter turn from the direction of travel, toward positive y for a line heading along x.
    static func normal(from a: CGPoint, to b: CGPoint) -> CGVector {
        let direction = GuidedStroke.direction(from: a, to: b)
        return CGVector(dx: -direction.dy, dy: direction.dx)
    }

    static func offset(_ point: CGPoint, _ direction: CGVector, _ distance: CGFloat) -> CGPoint {
        CGPoint(x: point.x + direction.dx * distance, y: point.y + direction.dy * distance)
    }

    static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}
