import CoreGraphics
import Foundation
import Testing
@testable import PrettyDrawKit

private func hand(_ width: CGFloat) -> Pen {
    Pen(width: width, style: .handDrawn)
}

// All of a mark's ink as one path.
private func joined(_ ink: [CGPath]) -> CGPath {
    let path = CGMutablePath()
    ink.forEach { path.addPath($0) }
    return path
}

private func path(of mark: Mark) -> CGPath {
    switch mark.kind {
    case .stroke(let points, let closed, let pen):
        return joined(HandDrawn.stroke(points, closed: closed, width: pen.width, seed: mark.seed))
    case .arrow(let from, let to, let pen):
        return joined(HandDrawn.arrow(from: from, to: to, width: pen.width, seed: mark.seed))
    case .rectangle(let rect, let pen):
        return joined(HandDrawn.rectangle(rect, width: pen.width, seed: mark.seed))
    case .text:
        preconditionFailure("Text isn't drawn by HandDrawn")
    }
}

private func guided(_ name: String, width: CGFloat) -> Mark.Kind {
    let sample = SampleStrokes.all().first { $0.name == name }!
    var stroke = GuidedStroke(start: sample.points[0], width: width)
    sample.points.dropFirst().forEach { stroke.add($0) }
    let result = stroke.finished(closingLoops: true)
    return .stroke(points: result.points, closed: result.closed, pen: hand(width))
}

private func mark(_ kind: Mark.Kind) -> Mark {
    Mark(display: 1, color: Palette.classic.colors[0], kind: kind)
}

@Suite struct HandDrawnTests {
    @Test func aMarkDrawsTheSameWayEveryTime() {
        let rectangle = mark(.rectangle(CGRect(x: 10, y: 10, width: 200, height: 120), pen: hand(11)))
        #expect(path(of: rectangle) == path(of: rectangle))
        let arrow = mark(.arrow(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 300, y: 100), pen: hand(11)))
        #expect(path(of: arrow) == path(of: arrow))
    }

    @Test func eachMarkHasItsOwnWobble() {
        let kind = Mark.Kind.rectangle(CGRect(x: 10, y: 10, width: 200, height: 120), pen: hand(11))
        let first = mark(kind), second = mark(kind)
        #expect(first.seed != second.seed)
        #expect(path(of: first) != path(of: second))
    }

    // The canvas only redraws within a mark's bounds, so ink outside them would be left behind or cut off.
    @Test func inkStaysWithinTheMarksBounds() {
        var kinds: [Mark.Kind] = []
        for width in [2, 11, 32] as [CGFloat] {
            kinds += ["underline", "circle", "oval", "check", "box", "tick"].map { guided($0, width: width) }
            kinds += [
                .stroke(points: [CGPoint(x: 0, y: 0), CGPoint(x: 400, y: 0)], closed: false, pen: hand(width)),
                .rectangle(CGRect(x: 0, y: 0, width: 600, height: 400), pen: hand(width)),
                .rectangle(CGRect(x: 0, y: 0, width: 30, height: 12), pen: hand(width)),
                .rectangle(CGRect(x: 0, y: 0, width: 300, height: 0), pen: hand(width)),
                .arrow(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 500, y: 300), pen: hand(width)),
                .arrow(from: CGPoint(x: 0, y: 0), to: CGPoint(x: -20, y: 6), pen: hand(width)),
            ]
        }
        for kind in kinds {
            for _ in 0..<40 {
                let ink = path(of: mark(kind)).boundingBoxOfPath
                let bounds = MarkRenderer.bounds(of: kind)
                #expect(bounds.contains(ink), "\(kind) drew \(ink), outside \(bounds)")
            }
        }
    }

    // Every part of the ink must turn the same way, or where they overlap the nonzero fill leaves a hole.
    @Test func inkHasNoHolesEvenOnSharpTurns() {
        let width: CGFloat = 11
        for name in ["check", "tick", "wave", "box"] {
            guard case .stroke(let points, let closed, _) = guided(name, width: width) else { continue }
            let ink = joined(HandDrawn.stroke(points, closed: closed, width: width, seed: 3))
            for point in points {
                #expect(ink.contains(point, using: .winding), "\(name) has a hole at \(point)")
            }
        }
        // A hairpin, much tighter than the line is wide.
        let hairpin = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0), CGPoint(x: 100, y: 3), CGPoint(x: 0, y: 3)]
        let ink = joined(HandDrawn.stroke(hairpin, closed: false, width: width, seed: 3))
        for point in GuidedStroke.resample(hairpin, spacing: 1) {
            #expect(ink.contains(point, using: .winding), "the hairpin has a hole at \(point)")
        }
    }

    @Test func inkIsAboutTheLineWidthAwayFromItsEnds() {
        let width: CGFloat = 11
        let ink = joined(HandDrawn.stroke([CGPoint(x: 0, y: 0), CGPoint(x: 600, y: 0)], closed: false, width: width, seed: 5))
        for x in stride(from: CGFloat(150), through: 450, by: 25) {
            #expect(ink.contains(CGPoint(x: x, y: 0.44 * width), using: .winding))
            #expect(!ink.contains(CGPoint(x: x, y: 0.56 * width), using: .winding))
        }
    }

    // Ink that overlaps along a whole line is slow to fill in one go, so each path covers only a short stretch of it.
    @Test func inkComesInShortStretches() {
        let width: CGFloat = 11
        let reach = CGFloat(HandDrawn.runLength) * HandDrawn.spacing + 2 * HandDrawn.inkRadius(width: width)
        let line = HandDrawn.stroke([CGPoint(x: 0, y: 0), CGPoint(x: 900, y: 0)], closed: false, width: width, seed: 5)
        let sides = HandDrawn.rectangle(CGRect(x: 0, y: 0, width: 900, height: 600), width: width, seed: 5)
        for path in line + sides {
            let box = path.boundingBoxOfPath
            #expect(max(box.width, box.height) <= reach + 0.01, "one path covers \(box)")
        }
    }

    @Test func aDotIsARoundBlob() {
        let ink = joined(HandDrawn.stroke([CGPoint(x: 50, y: 50)], closed: false, width: 10, seed: 1))
        let box = ink.boundingBoxOfPath
        #expect(abs(box.width - 10) < 0.01 && abs(box.height - 10) < 0.01)
        #expect(abs(box.midX - 50) < 0.01 && abs(box.midY - 50) < 0.01)
    }
}
