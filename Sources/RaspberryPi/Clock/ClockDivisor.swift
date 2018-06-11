//
//  ClockDivisor.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/10/18.
//

import Util

/// Clock divisor register.
///
/// Provides an type that encapsulates the clock divisor register, permitted values to be
/// initialized from integer or fractional components:
///
///     let divisor = ClockDivisor(integer: 82, fractional: 503)
///
/// Or by providing a float value to use as an upper bound:
///
///     let divisor = ClockDivisor(upperBound: 82.123)
///
/// The `integer` and `fractional` parts can be manipulated directly, and the value can be
/// assigned to `Clock.divisor`:
///
///     clock.divisor = ClockDivisor(upperBoard: 91.5)
///
public struct ClockDivisor : RawRepresentable, Equatable, Hashable, CustomStringConvertible {
    
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = (0x5a << 24) | rawValue
    }
    
    public init() {
        self.init(rawValue: 0)
    }
    
    public init(integer: Int, fractional: Int) {
        assert(integer >= 0 && integer < 4096, "integer out of range")
        assert(fractional >= 0 && fractional < 4096, "fractional out of range")
        self.init(rawValue: (UInt32(integer) << 12) | UInt32(fractional))
    }
    
    public init<T: BinaryFloatingPoint>(upperBound value: T) {
        assert(value >= 0 && value < 4096, "value out of range")
        self.init(integer: Int(value), fractional: Int(4096 * (value - value.rounded(.towardZero)))
        )
    }
    
    /// Divisor integer component.
    ///
    /// The value must be less than 4096.
    public var integer: Int {
        get {
            return Int((rawValue >> 12) & UInt32.mask(bits: 12))
        }
        set {
            assert(newValue >= 0 && newValue < (1 << 12), "integer out of range")
            self = ClockDivisor(rawValue: rawValue & UInt32.mask(except: 12, offset: 12) | (UInt32(newValue) << 12))
        }
    }
    
    /// Divisor fractional component.
    ///
    /// The value is used as a fraction of 4096, for example 2048 represents 0.5.
    ///
    /// The value must be less than 4096.
    public var fractional: Int {
        get {
            return Int(rawValue & UInt32.mask(bits: 12))
        }
        set {
            assert(newValue >= 0 && newValue < (1 << 12), "fractional out of range")
            self = ClockDivisor(rawValue: rawValue & UInt32.mask(except: 12) | UInt32(newValue))
        }
    }
    
    /// Float equivalent of the divisor.
    public var floatValue: Float {
        return Float(integer) + Float(fractional) / 4096
    }
    
    public var description: String {
        return floatValue.description
    }
    
}
