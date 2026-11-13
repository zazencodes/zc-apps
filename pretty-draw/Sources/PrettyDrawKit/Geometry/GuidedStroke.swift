import CoreGraphics
import Foundation

// A freehand stroke being drawn. It smooths the hand's path as points arrive, so the line on screen is already clean,
// and when the stroke ends it trims hooks and closes loops that come back around to their start.
public struct GuidedStroke {
    // Points along the smoothed stroke are this far apart.
    static let spacing: CGFloat = 2

    public private(set) var raw: [CGPoint]
    public let width: CGFloat

    public init(start: CGPoint, width: CGFloat) {
        raw = [start]
        self.width = width
    }

    public mutating func add(_ point: CGPoint) {
        guard hypot(point.x - raw.last!.x, point.y - raw.last!.y) >= 0.5 else { return }
        raw.append(point)
    }

    // How far, in points, smoothing reaches along the stroke. Thicker lines hide more and can take more.
    var sigma: CGFloat { 9 + 0.3 * width }

    // The stroke as it looks while it's being drawn: smoothed, ending right at the pointer.
    public var live: [CGPoint] {
        let points = Self.resample(raw, spacing: Self.spacing)
        return Self.smooth(points, sigma: sigma(for: points), closed: false)
    }

    // The stroke as it's kept. `closed` means the points form a loop. With `closingLoops`, a stroke that comes back
    // around to where it began becomes one. Without it, every stroke stays open, overshoot and all.
    public func finished(closingLoops: Bool) -> (points: [CGPoint], closed: Bool) {
        let result = finishedWithGuidance(closingLoops: closingLoops)
        return (result.points, result.closed)
    }

    // `guidance` is how far, from 0 to 1, the stroke was pulled toward a clean shape.
    func finishedWithGuidance(closingLoops: Bool) -> (points: [CGPoint], closed: Bool, guidance: CGFloat) {
        let points = Self.removingHooks(Self.resample(raw, spacing: Self.spacing), width: width)
        if closingLoops, let loop = Self.loop(in: points, width: width) {
            let perimeter = Self.length(loop)
            let smoothed = Self.smooth(loop, sigma: max(sigma, perimeter / 38), closed: true)
            let guided = Self.guide(smoothed, toward: Self.ellipse(fitting: smoothed), near: 0.035, far: 0.085)
            return (guided.points, true, guided.weight)
        }
        let smoothed = Self.smooth(points, sigma: sigma(for: points), closed: false)
        guard smoothed.count > 8 else { return (smoothed, false, 0) }
        let guided = Self.guide(smoothed, toward: Self.sweep(smoothed), near: 0.012, far: 0.035)
        return (guided.points, false, guided.weight)
    }

    // Short strokes get gentler smoothing, so a small tick or cross keeps its shape.
    private func sigma(for points: [CGPoint]) -> CGFloat {
        min(sigma, Self.length(points) / 7)
    }

    // MARK: - Geometry

    static func length(_ points: [CGPoint]) -> CGFloat {
        zip(points, points.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(b.x - a.x, b.y - a.y)
    }

    // Evenly spaced points along the path. The last point is always kept.
    static func resample(_ points: [CGPoint], spacing: CGFloat) -> [CGPoint] {
        guard var previous = points.first else { return [] }
        var result = [previous]
        var carried: CGFloat = 0
        for point in points.dropFirst() {
            var segment = distance(previous, point)
            var start = previous
            while carried + segment >= spacing {
                let t = (spacing - carried) / segment
                let next = CGPoint(x: start.x + (point.x - start.x) * t, y: start.y + (point.y - start.y) * t)
                result.append(next)
                segment -= spacing - carried
                start = next
                carried = 0
            }
            carried += segment
            previous = point
        }
        if let last = points.last, distance(result.last!, last) > 0.01 {
            result.append(last)
        }
        return result
    }

    // Gaussian smoothing over evenly spaced points. Open strokes are reflected through their end points, which keeps
    // both ends exactly where they were drawn. Closed strokes wrap around.
    static func smooth(_ points: [CGPoint], sigma: CGFloat, closed: Bool) -> [CGPoint] {
        let count = points.count
        let s = sigma / spacing
        guard count > 2, s > 0.5 else { return points }
        let radius = Int((3 * s).rounded(.up))
        let weights = (0...radius).map { exp(-CGFloat($0 * $0) / (2 * s * s)) }

        func sample(_ index: Int) -> CGPoint {
            if closed {
                return points[((index % count) + count) % count]
            }
            if index < 0 {
                let mirror = points[min(-index, count - 1)]
                return CGPoint(x: 2 * points[0].x - mirror.x, y: 2 * points[0].y - mirror.y)
            }
            if index >= count {
                let last = count - 1
                let mirror = points[max(2 * last - index, 0)]
                return CGPoint(x: 2 * points[last].x - mirror.x, y: 2 * points[last].y - mirror.y)
            }
            return points[index]
        }

        return (0..<count).map { index in
            var x = weights[0] * points[index].x
            var y = weights[0] * points[index].y
            var total = weights[0]
            for offset in 1...radius {
                let before = sample(index - offset)
                let after = sample(index + offset)
                x += weights[offset] * (before.x + after.x)
                y += weights[offset] * (before.y + after.y)
                total += 2 * weights[offset]
            }
            return CGPoint(x: x / total, y: y / total)
        }
    }

    // Drops a short flick at either end that turns sharply away from the rest of the stroke, as happens when the
    // pointer twitches on press or release.
    static func removingHooks(_ points: [CGPoint], width: CGFloat) -> [CGPoint] {
        let hook = max(10, 1.2 * width)
        guard length(points) > 6 * hook else { return points }

        // How many points at the start of `points` form a hook.
        func hookLength(_ points: [CGPoint]) -> Int {
            let span = 3
            var travelled: CGFloat = 0
            var sharpest: (index: Int, cosine: CGFloat)?
            for index in 1..<(points.count - span) {
                travelled += distance(points[index - 1], points[index])
                guard travelled <= hook else { break }
                let tip = direction(from: points[index], to: points[max(index - span, 0)])
                let body = direction(from: points[index + span], to: points[index])
                let cosine = tip.dx * body.dx + tip.dy * body.dy
                if cosine < sharpest?.cosine ?? 1 {
                    sharpest = (index, cosine)
                }
            }
            guard let sharpest, sharpest.cosine < 0.7 else { return 0 }
            return sharpest.index
        }

        let start = hookLength(points)
        let end = hookLength(Array(points.reversed()))
        return Array(points[start..<(points.count - end)])
    }

    // When the stroke comes back around to where it began, returns just the loop, without the lead-in before the
    // meeting point or the overshoot after it.
    static func loop(in points: [CGPoint], width: CGFloat) -> [CGPoint]? {
        let count = points.count
        guard count > 24 else { return nil }
        let diagonal = diagonal(of: points)
        guard diagonal > 40 else { return nil }

        let reach = 0.18 * diagonal + width / 2
        let head = 0..<(count * 3 / 10)
        let tail = (count * 6 / 10)..<count
        let span = 4
        var best: (start: Int, end: Int, gap: CGFloat)?
        for i in head {
            for j in tail {
                let gap = distance(points[i], points[j])
                guard gap < reach, gap < best?.gap ?? .infinity else { continue }
                // Going around a loop, the stroke meets its start heading the same way. The two arms of a V or a U
                // meet head on.
                let first = direction(from: points[max(i - span, 0)], to: points[min(i + span, count - 1)])
                let last = direction(from: points[max(j - span, 0)], to: points[min(j + span, count - 1)])
                guard first.dx * last.dx + first.dy * last.dy > 0.4 else { continue }
                best = (i, j, gap)
            }
        }
        guard let best else { return nil }
        let loop = Array(points[best.start...best.end])
        guard abs(turning(of: smooth(loop, sigma: 6, closed: true))) > 1.6 * .pi else { return nil }
        return loop
    }

    // MARK: - Guidance

    // Pulls a stroke toward a clean version of itself. The closer the stroke already is, the harder the pull: a
    // wobbly circle becomes round, while a stroke that's clearly meant to be some other shape is left alone.
    // `near` and `far` are distances from the clean shape, as fractions of the stroke's size.
    static func guide(_ points: [CGPoint], toward clean: [CGPoint], near: CGFloat, far: CGFloat)
        -> (points: [CGPoint], weight: CGFloat)
    {
        let squared = zip(points, clean).reduce(CGFloat(0)) { total, pair in
            let d = distance(pair.0, pair.1)
            return total + d * d
        }
        let deviation = sqrt(squared / CGFloat(points.count)) / max(diagonal(of: points), 1)
        let weight = min(max((far - deviation) / (far - near), 0), 1)
        guard weight > 0 else { return (points, 0) }
        let guided = zip(points, clean).map { point, target in
            CGPoint(x: point.x + (target.x - point.x) * weight, y: point.y + (target.y - point.y) * weight)
        }
        return (guided, weight)
    }

    // The closest ellipse, as the point on it that matches each point of the loop. A circled area reads best as a clean
    // round or oval shape.
    //
    // An ellipse is center + a·cos t + b·sin t. Given each point's t, the best center, a and b are a linear least-squares
    // fit; given the ellipse, each point's t is its angle once the ellipse is mapped to a unit circle. Alternating the
    // two settles in a few rounds. The first guess spaces t evenly around the loop.
    static func ellipse(fitting points: [CGPoint]) -> [CGPoint] {
        let count = points.count
        var parameters = (0..<count).map { 2 * .pi * CGFloat($0) / CGFloat(count) }
        var center = CGPoint.zero, a = CGVector.zero, b = CGVector.zero
        for _ in 0..<6 {
            // Normal equations for the basis 1, cos t, sin t, shared by x and y.
            var m = [[CGFloat]](repeating: [0, 0, 0], count: 3)
            var rx: [CGFloat] = [0, 0, 0], ry: [CGFloat] = [0, 0, 0]
            for (t, point) in zip(parameters, points) {
                let basis = [1, cos(t), sin(t)]
                for row in 0..<3 {
                    for column in 0..<3 { m[row][column] += basis[row] * basis[column] }
                    rx[row] += basis[row] * point.x
                    ry[row] += basis[row] * point.y
                }
            }
            guard let x = solve(m, rx), let y = solve(m, ry) else { return points }
            center = CGPoint(x: x[0], y: y[0])
            a = CGVector(dx: x[1], dy: y[1])
            b = CGVector(dx: x[2], dy: y[2])
            let determinant = a.dx * b.dy - b.dx * a.dy
            guard abs(determinant) > 1e-6 else { return points }
            parameters = points.map { point in
                let dx = point.x - center.x, dy = point.y - center.y
                let cosine = (b.dy * dx - b.dx * dy) / determinant
                let sine = (a.dx * dy - a.dy * dx) / determinant
                return atan2(sine, cosine)
            }
        }
        return parameters.map { t in
            CGPoint(x: center.x + a.dx * cos(t) + b.dx * sin(t), y: center.y + a.dy * cos(t) + b.dy * sin(t))
        }
    }

    // Solves a 3×3 linear system by Cramer's rule.
    static func solve(_ m: [[CGFloat]], _ r: [CGFloat]) -> [CGFloat]? {
        func determinant(_ m: [[CGFloat]]) -> CGFloat {
            let first = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
            let second = m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
            let third = m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])
            return first - second + third
        }
        let d = determinant(m)
        guard abs(d) > 1e-9 else { return nil }
        return (0..<3).map { column in
            var replaced = m
            for row in 0..<3 { replaced[row][column] = r[row] }
            return determinant(replaced) / d
        }
    }

    // The closest single smooth sweep between the stroke's ends: a quadratic curve, so a slightly sagging underline
    // keeps its sag but loses its wobble.
    static func sweep(_ points: [CGPoint]) -> [CGPoint] {
        let start = points.first!, end = points.last!
        let total = length(points)
        guard total > 0 else { return points }
        var travelled: CGFloat = 0
        var parameters: [CGFloat] = [0]
        for (a, b) in zip(points, points.dropFirst()) {
            travelled += distance(a, b)
            parameters.append(travelled / total)
        }
        // Least squares for the middle control point, with the ends fixed.
        var weight: CGFloat = 0, x: CGFloat = 0, y: CGFloat = 0
        for (t, point) in zip(parameters, points) {
            let a = 2 * t * (1 - t)
            let restX = point.x - (1 - t) * (1 - t) * start.x - t * t * end.x
            let restY = point.y - (1 - t) * (1 - t) * start.y - t * t * end.y
            weight += a * a
            x += a * restX
            y += a * restY
        }
        guard weight > 0 else { return points }
        let control = CGPoint(x: x / weight, y: y / weight)
        return parameters.map { t -> CGPoint in
            let a: CGFloat = (1 - t) * (1 - t)
            let b: CGFloat = 2 * t * (1 - t)
            let c: CGFloat = t * t
            return CGPoint(
                x: a * start.x + b * control.x + c * end.x,
                y: a * start.y + b * control.y + c * end.y
            )
        }
    }

    static func diagonal(of points: [CGPoint]) -> CGFloat {
        let box = MarkRenderer.boundingBox(points)
        return hypot(box.width, box.height)
    }

    static func direction(from a: CGPoint, to b: CGPoint) -> CGVector {
        let d = distance(a, b)
        return d > 0 ? CGVector(dx: (b.x - a.x) / d, dy: (b.y - a.y) / d) : CGVector(dx: 0, dy: 0)
    }

    // Total signed change of direction around a closed path, in radians.
    static func turning(of points: [CGPoint]) -> CGFloat {
        let count = points.count
        guard count > 2 else { return 0 }
        var total: CGFloat = 0
        for index in 0..<count {
            let a = points[index], b = points[(index + 1) % count], c = points[(index + 2) % count]
            let first = atan2(b.y - a.y, b.x - a.x)
            let second = atan2(c.y - b.y, c.x - b.x)
            var change = second - first
            while change > .pi { change -= 2 * .pi }
            while change < -.pi { change += 2 * .pi }
            total += change
        }
        return total
    }

    // Evenly spaced points, exactly `count` of them, used to morph one stroke into another.
    static func resample(_ points: [CGPoint], count: Int) -> [CGPoint] {
        guard points.count > 1, count > 1 else { return Array(repeating: points.first ?? .zero, count: max(count, 1)) }
        let total = length(points)
        guard total > 0 else { return Array(repeating: points[0], count: count) }
        var result: [CGPoint] = []
        result.reserveCapacity(count)
        var index = 0
        var travelled: CGFloat = 0
        for k in 0..<count {
            let target = total * CGFloat(k) / CGFloat(count - 1)
            while index < points.count - 2, travelled + distance(points[index], points[index + 1]) < target {
                travelled += distance(points[index], points[index + 1])
                index += 1
            }
            let segment = distance(points[index], points[index + 1])
            let t = segment > 0 ? min(max((target - travelled) / segment, 0), 1) : 0
            let a = points[index], b = points[index + 1]
            result.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
        }
        return result
    }
}
