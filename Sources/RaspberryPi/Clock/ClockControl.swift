//
//  ClockControl.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/10/18.
//

import Util

/// Clock control register.
///
/// Provides an type conforming to `OptionSet` that allows direct manipulation of a clock control
/// register as a set of enumerated constants.
///
///     var control: ClockControl = [ .source(.pwm), .mash(.none), .enabled ]
///     clock.registers.control.pointee = control
///
public struct ClockControl : OptionSet, Equatable, Hashable {
    
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = (0x5a << 24) | rawValue
    }
    
    public static let invertOutput = ClockControl(rawValue: 1 << 8)
    public static let running      = ClockControl(rawValue: 1 << 7)
    public static let kill         = ClockControl(rawValue: 1 << 5)
    public static let enabled      = ClockControl(rawValue: 1 << 4)
    
    public static func mash(_ mash: Int) -> ClockControl {
        assert(mash >= 0 && mash <= 3, "mash out of range")
        return ClockControl(rawValue: UInt32(mash) << 9)
    }
    
    public static func source(_ source: ClockSource) -> ClockControl {
        return ClockControl(rawValue: source.rawValue)
    }
    
    /// Timing source.
    ///
    /// This is an internal method, access is provided through `Clock`.
    internal var source: ClockSource {
        get {
            return ClockSource(rawValue: rawValue & UInt32.mask(bits: 4)) ?? .none
        }
        set {
            self = ClockControl(rawValue: rawValue & UInt32.mask(except: 4) | newValue.rawValue)
        }
    }
    
    /// Noise-shaping MASH filter.
    ///
    /// This is an internal method, access is provided through `Clock`.
    internal var mash: Int {
        get {
            return Int((rawValue >> 9) & UInt32.mask(bits: 2))
        }
        set {
            assert(newValue >= 0 && newValue <= 3, "mash out of range")
            self = ClockControl(rawValue: rawValue & UInt32.mask(except: 2, offset: 9) | (UInt32(newValue) << 9))
        }
    }
    
}

// MARK: Debugging

extension ClockControl : CustomDebugStringConvertible {
    
    public var debugDescription: String {
        var parts: [String] = []
        
        parts.append(".source(.\(source))")
        parts.append(".mash(.\(mash))")
        
        if contains(.invertOutput) { parts.append(".invertOutput") }
        if contains(.running) { parts.append(".running") }
        if contains(.kill) { parts.append(".kill") }
        if contains(.enabled) { parts.append(".enabled") }
        
        return "[" + parts.joined(separator: ", ") + "]"
    }
    
}
