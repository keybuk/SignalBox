//
//  ClockSource.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/10/18.
//

/// Clock sources.
public enum ClockSource : UInt32 {
    
    case none       = 0
    case oscillator = 1
    case testDebug0 = 2
    case testDebug1 = 3
    case plla       = 4
    case pllc       = 5
    case plld       = 6
    case hdmiAux    = 7

    internal static let allCases: [ClockSource] = [.none, .oscillator, .testDebug0, .testDebug1,
                                                   .plla, .pllc, .plld, .hdmiAux ]
    
    /// Clock's known frequency (in MHz).
    public var frequency: Float {
        switch self {
        case .oscillator: return 19.2
        // Note: .pllc is ommitted since its value is not stable.
        case .plld: return 500
        case .hdmiAux: return 216
        default: return 0
        }
    }

    /// Return valid divisor for a target cycle time.
    ///
    /// - Parameters:
    ///   - cycle: cycle time in µs.
    ///   - mash: number of stages of MASH filter to use.
    ///
    /// - Returns: `ClockDivisor` for this clock to reach as closed to `cycle` as is possible,
    /// else `nil` if no valid result is possible.
    internal func divisor(for cycle: Float, mash: Int) -> ClockDivisor? {
        // Since `cycle` is in µs and `frequency` is MHz the 1,000,000s cancel out so we can
        // calculate the divisor by just multiplying the two numbers together.
        let value = frequency * cycle
        guard value > 0 && value < 4096 else { return nil }

        var divisor = ClockDivisor(upperBound: value)
        if mash == 0 {
            guard divisor.integer > 0 else { return nil }
            divisor.fractional = 0
        }

        return divisor
    }

}
