import CoreGraphics
import Testing
@testable import PrettyDrawKit

private func stroke(_ name: String, width: CGFloat = 11) -> GuidedStroke {
    let sample = SampleStrokes.all().first { $0.name == name }!
    var stroke = GuidedStroke(start: sample.points[0], width: width)
    sample.points.dropFirst().forEach { stroke.add($0) }
    return stroke
}

// Largest distance from any point to the straight line between the ends.
private func sag(_ points: [CGPoint]) -> CGFloat {
    let a = points.first!, b = points.last!
    let length = GuidedStroke.distance(a, b)
    return points.map { p in abs((b.x - a.x) * (a.y - p.y) - (a.x - p.x) * (b.y - a.y)) / length }.max()!
}

// How far the direction turns between neighbouring segments, summed: zero for a straight line, larger for jitter.
private func wiggle(_ points: [CGPoint]) -> CGFloat {
    let spaced = GuidedStroke.resample(points, spacing: 4)
    var total: CGFloat = 0
    for index in 1..<(spaced.count - 1) {
        let first = GuidedStroke.direction(from: spaced[index - 1], to: spaced[index])
        let second = GuidedStroke.direction(from: spaced[index], to: spaced[index + 1])
        total += acos(min(max(first.dx * second.dx + first.dy * second.dy, -1), 1))
    }
    return total
}

@Suite struct GuidedStrokeTests {
    @Test func resamplingSpacesPointsEvenlyAndKeepsTheEnds() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 7)]
        let resampled = GuidedStroke.resample(points, spacing: 2)
        #expect(resampled.first == points.first)
        #expect(resampled.last == points.last)
        for (a, b) in zip(resampled, resampled.dropFirst().dropLast()) {
            #expect(abs(GuidedStroke.distance(a, b) - 2) < 0.001)
        }
    }

    @Test func smoothingAnOpenStrokeKeepsItsEnds() {
        let sample = stroke("wave")
        let live = sample.live
        #expect(GuidedStroke.distance(live.first!, sample.raw.first!) < 0.01)
        #expect(GuidedStroke.distance(live.last!, sample.raw.last!) < 0.01)
    }

    @Test func liveStrokeIsSmootherThanTheInput() {
        let sample = stroke("wave")
        #expect(wiggle(sample.live) < wiggle(sample.raw) / 3)
    }

    @Test func underlineBecomesOneCleanSweepWithoutItsFlick() {
        let sample = stroke("underline")
        let result = sample.finishedWithGuidance(closingLoops: true)
        #expect(!result.closed)
        #expect(result.guidance == 1)
        // The release flick went up by 9 points. Without it the stroke ends level with the line.
        #expect(abs(result.points.last!.y - result.points.first!.y) < 6)
        #expect(sag(result.points) < 12)
        #expect(wiggle(result.points) < 0.3)
    }

    @Test func circleClosesIntoAnEllipse() {
        let result = stroke("circle").finishedWithGuidance(closingLoops: true)
        #expect(result.closed)
        #expect(result.guidance == 1)
        // Every point sits on one ellipse, so the radius changes smoothly: no lumps left.
        let center = CGPoint(
            x: result.points.map(\.x).reduce(0, +) / CGFloat(result.points.count),
            y: result.points.map(\.y).reduce(0, +) / CGFloat(result.points.count)
        )
        let radii = result.points.map { GuidedStroke.distance($0, center) }
        let steps = zip(radii, radii.dropFirst()).map { abs($0.1 - $0.0) }
        #expect(steps.max()! < 1)
    }

    @Test func loopSkipsTheOvershootPastItsStart() {
        let sample = stroke("circle")
        let result = sample.finished(closingLoops: true)
        // The raw circle overshoots by about 50°, so the loop is clearly shorter than what was drawn.
        #expect(GuidedStroke.length(result.points) < 0.9 * GuidedStroke.length(sample.raw))
    }

    @Test(arguments: ["circle", "oval", "box"])
    func withLoopClosingOffLoopsStayAsDrawn(name: String) {
        let sample = stroke(name)
        let open = sample.finished(closingLoops: false)
        #expect(!open.closed)
        // The overshoot and lead-in stay, so the line is about as long as what was drawn.
        #expect(GuidedStroke.length(open.points) > 0.9 * GuidedStroke.length(sample.finished(closingLoops: true).points))
        #expect(GuidedStroke.distance(open.points.last!, sample.raw.last!) < 20)
    }

    @Test func ovalThatEndsShortStillCloses() {
        #expect(stroke("oval").finished(closingLoops: true).closed)
    }

    @Test(arguments: ["check", "tick", "u-turn", "wave", "underline"])
    func openShapesStayOpen(name: String) {
        #expect(!stroke(name).finished(closingLoops: true).closed)
    }

    @Test(arguments: ["check", "wave", "box", "u-turn"])
    func shapesFarFromACleanOneAreLeftAlone(name: String) {
        #expect(stroke(name).finishedWithGuidance(closingLoops: true).guidance == 0)
    }

    @Test func smallTickKeepsItsShape() {
        let sample = stroke("tick")
        let result = sample.finished(closingLoops: true)
        let box = MarkRenderer.boundingBox(result.points)
        let rawBox = MarkRenderer.boundingBox(sample.raw)
        #expect(box.width > 0.75 * rawBox.width)
        #expect(box.height > 0.6 * rawBox.height)
    }

    @Test func aClickMakesADot() {
        let result = GuidedStroke(start: CGPoint(x: 5, y: 5), width: 11).finished(closingLoops: true)
        #expect(result.points == [CGPoint(x: 5, y: 5)])
        #expect(!result.closed)
    }

    @Test func morphingResampleGivesTheRequestedCount() {
        let points = GuidedStroke.resample(stroke("wave").raw, count: 64)
        #expect(points.count == 64)
    }
}

@Suite struct ArrowGeometryTests {
    @Test func headArmsLeaveTheTipBackAlongTheShaft() {
        let arrow = ArrowGeometry(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 200, y: 0), width: 11)
        let box = arrow.path.boundingBox
        let head = ArrowGeometry.headLength(width: 11)
        #expect(box.maxX == 200)
        #expect(abs(box.height - 2 * head * sin(ArrowGeometry.headAngle)) < 0.01)
        #expect(abs(box.midY) < 0.01)
    }

    @Test func shortArrowShrinksItsHead() {
        let arrow = ArrowGeometry(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 12, y: 0), width: 11)
        #expect(arrow.path.boundingBox.minX >= 0)
    }
}
