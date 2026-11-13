import CoreGraphics

// SplitMix64: the same seed always gives the same numbers.
public struct SeededRandom {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    // A value in 0..<1.
    public mutating func next() -> CGFloat {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return CGFloat(z >> 11) / CGFloat(1 << 53)
    }
}

extension SeededRandom {
    // A value in the range.
    mutating func next(in range: ClosedRange<CGFloat>) -> CGFloat {
        range.lowerBound + (range.upperBound - range.lowerBound) * next()
    }

    // -1 or 1.
    mutating func sign() -> CGFloat {
        next() < 0.5 ? -1 : 1
    }
}
