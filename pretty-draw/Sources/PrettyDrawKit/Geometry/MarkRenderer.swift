import AppKit

// Draws marks into a flipped context (origin top left). Clean lines have round caps and joins, which gives rectangles
// their softly rounded outer corners. Hand-drawn lines are filled ink shapes from `HandDrawn`.
public enum MarkRenderer {
    // Draws everything except text, which the canvas shows with text views.
    public static func draw(_ mark: Mark, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setStrokeColor(mark.color.cgColor)
        context.setFillColor(mark.color.cgColor)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch mark.kind {
        case .stroke(let points, let closed, let pen):
            guard let first = points.first else { return }
            if points.count == 1 || GuidedStroke.length(points) < 0.5 {
                let width = pen.width
                context.fillEllipse(in: CGRect(x: first.x - width / 2, y: first.y - width / 2, width: width, height: width))
                return
            }
            switch pen.style {
            case .clean:
                context.setLineWidth(pen.width)
                context.addLines(between: points)
                if closed { context.closePath() }
                context.strokePath()
            case .handDrawn:
                fill(HandDrawn.stroke(points, closed: closed, width: pen.width, seed: mark.seed), in: context)
            }
        case .arrow(let from, let to, let pen):
            switch pen.style {
            case .clean:
                context.setLineWidth(pen.width)
                context.addPath(ArrowGeometry(from: from, to: to, width: pen.width).path)
                context.strokePath()
            case .handDrawn:
                fill(HandDrawn.arrow(from: from, to: to, width: pen.width, seed: mark.seed), in: context)
            }
        case .rectangle(let rect, let pen):
            switch pen.style {
            case .clean:
                context.setLineWidth(pen.width)
                context.stroke(rect.standardized)
            case .handDrawn:
                fill(HandDrawn.rectangle(rect.standardized, width: pen.width, seed: mark.seed), in: context)
            }
        case .text:
            break
        }
    }

    private static func fill(_ ink: [CGPath], in context: CGContext) {
        for path in ink {
            context.addPath(path)
            context.fillPath()
        }
    }

    // The area a mark covers, including its line width, for redrawing only what changed.
    public static func bounds(of kind: Mark.Kind) -> CGRect {
        switch kind {
        case .stroke(let points, _, let pen):
            let reach = pen.style == .clean ? pen.width : HandDrawn.strokeReach(width: pen.width)
            return boundingBox(points).insetBy(dx: -reach, dy: -reach)
        case .arrow(let from, let to, let pen):
            switch pen.style {
            case .clean:
                return ArrowGeometry(from: from, to: to, width: pen.width).path.boundingBox
                    .insetBy(dx: -pen.width, dy: -pen.width)
            case .handDrawn:
                let reach = HandDrawn.arrowReach(width: pen.width)
                return boundingBox([from, to]).insetBy(dx: -reach, dy: -reach)
            }
        case .rectangle(let rect, let pen):
            let reach = pen.style == .clean ? pen.width : HandDrawn.rectangleReach(width: pen.width)
            return rect.standardized.insetBy(dx: -reach, dy: -reach)
        case .text:
            return .null
        }
    }

    static func boundingBox(_ points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .null }
        var box = CGRect(origin: first, size: .zero)
        for point in points.dropFirst() {
            box = box.union(CGRect(origin: point, size: .zero))
        }
        return box
    }
}

// A straight arrow: a shaft running right up to the tip and an open head of two arms, all one line of the pen's width
// with round caps and joins, so the tip and the arm ends are rounded. The head's size follows the line width.
public struct ArrowGeometry {
    static let headAngle: CGFloat = 30 * .pi / 180

    public let path: CGPath

    public init(from: CGPoint, to: CGPoint, width: CGFloat) {
        let dx = to.x - from.x, dy = to.y - from.y
        let length = hypot(dx, dy)
        let back = length > 0 ? CGVector(dx: -dx / length, dy: -dy / length) : CGVector(dx: -1, dy: 0)
        let headLength = min(Self.headLength(width: width), length / 3)

        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        for side: CGFloat in [-1, 1] {
            let angle = side * Self.headAngle
            let arm = CGVector(
                dx: back.dx * cos(angle) - back.dy * sin(angle),
                dy: back.dx * sin(angle) + back.dy * cos(angle)
            )
            path.move(to: to)
            path.addLine(to: CGPoint(x: to.x + arm.dx * headLength, y: to.y + arm.dy * headLength))
        }
        self.path = path
    }

    // The longest each arm gets, from the tip to the middle of its rounded end. Shorter arrows get shorter arms.
    public static func headLength(width: CGFloat) -> CGFloat {
        1.6 * width + 14
    }
}
