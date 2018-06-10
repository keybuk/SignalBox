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
        return registers.pointee.control.contains(.busy)
    }
    
    /// Noise-shaping MASH filter.
    ///
    /// The average frequency of the generated clock will match the frequency of the source,
    /// divided by `divisor`. This is achieved by dropping or waiting additional ticks, above and
    /// below the intended frequency, in order to reach it.
    ///
    /// The amount of filter applied is adjusted by this setting.
    ///
    /// To avoid glitches, do not change while `isRunning` is `true`.
    public var mash: ClockMASH {
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
    
}

// MARK: Debugging

extension ClockGenerator : CustomDebugStringConvertible {
    
    public var debugDescription: String {
        return "<\(type(of: self)) \(identifier), control: \(registers.pointee.control), divisor: \(divisor)>"
    }
    
}
