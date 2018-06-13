//
//  ClockGenerator.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/10/18.
//

/// Single clock generator.
///
/// Instances of this class are vended by `Clock` and combine the reference to the vending `clock`
/// instance, and the specific clock `identifier`.
public final class ClockGenerator {
    
    /// Clocks instance.
    public let clock: Clock
    
    /// Clock identifier.
    public let identifier: ClockIdentifier
    
    public init(clock: Clock, identifier: ClockIdentifier) {
        self.clock = clock
        self.identifier = identifier
    }
    
    /// Pointer to registers for this specific clock.
    private var registers: UnsafeMutablePointer<Clock.Registers> {
        return clock.registers.advanced(by: identifier.offset / MemoryLayout<Clock.Registers>.stride)
    }
    
    /// Timing source.
    public var source: ClockSource {
        get { return registers.pointee.control.source }
        set { registers.pointee.control.source = newValue }
    }
    
    /// Clock generator is enabled.
    ///
    /// When this is set, it will not take effect immediately but at the next clock cycle. Check
    /// the value of `isRunning` to once the clock generator has changed.
    public var isEnabled: Bool {
        get { return registers.pointee.control.contains(.enabled) }
        set {
            if newValue {
                registers.pointee.control.insert(.enabled)
            } else {
                registers.pointee.control.remove(.enabled)
            }
        }
    }
    
    /// Clock generator is running.
    ///
    /// To avoid glitches, `source`, `mash`, and `divisor` should not be changed while this is
    /// `true`.
    public var isRunning: Bool {
        return registers.pointee.control.contains(.running)
    }
    
    /// Noise-shaping MASH filter.
    ///
    /// The average frequency of the generated clock will match the frequency of the source,
    /// divided by `divisor`. This is achieved by dropping or waiting additional ticks, above and
    /// below the intended frequency, in order to reach it.
    ///
    /// The amount of filter applied is adjusted by this setting, in the range 0...3.
    ///
    /// To avoid glitches, do not change while `isRunning` is `true`.
    public var mash: Int {
        get { return registers.pointee.control.mash }
        set { registers.pointee.control.mash = newValue }
    }
    
    /// Frequency divisor.
    ///
    /// Sets the average frequency of the generated clock as a division of the frequency of the
    /// source clock.
    ///
    /// The divisor consists of two parts, an integer and a fractional part; the easiest way to
    /// initialize is to give a float for the upper bound, but they can be provided directly:
    ///
    ///     let divisor = ClockDivisor(upperBound: 82.123)
    ///     // Equivalent to:
    ///     let divisor = ClockDivisor(integer: 82, fractional: 503)
    ///
    /// The divisor must be less than 4096.
    ///
    /// To avoid glitches, do not change while `isRunning` is `true`.
    public var divisor: ClockDivisor {
        get { return registers.pointee.divisor }
        set { registers.pointee.divisor = newValue }
    }

    /// Configure the clock for a target cycle time.
    ///
    /// Sets the clock `source` and `divisor` to reach the closest cycle time to `cycle` as it is
    /// possible to reach.
    ///
    /// - Parameters:
    ///   - cycle: cycle time in µs.
    ///   - mash: number of stages of MASH filter to use.
    ///
    /// - Returns: cycle time the clock has been configured for. This may not be the requested
    ///   time, but will be the closest that can be configured. If no clock can provide that value
    ///   `nil` is returned.
    public func configure(forCycle cycle: Float, mash: Int) -> Float? {
        assert(cycle > 0, "cycle out of range")

        var bestCycle: Float?
        for source in ClockSource.allCases {
            guard source != .hdmiAux else { continue }
            guard let divisor = source.divisor(for: cycle, mash: mash) else { continue }

            let thisCycle = divisor.floatValue / source.frequency
            if bestCycle == nil || abs(cycle - thisCycle) < abs(cycle - bestCycle!) {
                bestCycle = thisCycle
                self.source = source
                self.divisor = divisor
                self.mash = mash
            }
        }

        return bestCycle
    }

    /// Configure the clock for a target frequency.
    ///
    /// Sets the clock `source` and `divisor` to reach the closest frequency to `frequency` as it
    /// is possible to reach.
    ///
    /// - Parameters:
    ///   - frequency: desired frequency in MHz.
    ///   - mash: number of stages of MASH filter to use.
    ///
    /// - Returns: frequency the clock has been configured for. This may not be the requested
    ///   frequency, but will be the closest that can be configured. If no clock can provide that
    ///   value `nil` is returned.
    public func configure(forFrequency frequency: Float, mash: Int) -> Float? {
        assert(frequency > 0, "frequency out of range")
        return configure(forCycle: 1 / frequency, mash: mash).map { 1 / $0 }
    }

}


// MARK: Debugging

extension ClockGenerator : CustomDebugStringConvertible {
    
    public var debugDescription: String {
        var parts: [String] = []
        
        parts.append("\(type(of: self)) \(identifier)")
        parts.append("control: \(registers.pointee.control)")
        parts.append("divisor: \(divisor)")
        
        return "<" + parts.joined(separator: ", ") + ">"
    }
    
}
