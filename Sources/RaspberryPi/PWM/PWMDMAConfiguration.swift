//
//  PWMDMAConfiguration.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/10/18.
//

import Util

/// PWM DMA configuration register.
///
/// Provides an type conforming to `OptionSet` that allows direct manipulation of the PWM DMA
/// configuration registers as a set of enumerated constants.
///
///     var config: PWMDMAConfiguration = [ .enabled, .panicThreshold(15)., dataRequestThreshold(15) ]
///     pwm.registers.dmaConfiguration.pointee = config
///
public struct PWMDMAConfiguration : OptionSet, Equatable, Hashable {
    
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public static let enabled = PWMDMAConfiguration(rawValue: 1 << 31)
    
    public static func panicThreshold(_ threshold: Int) -> PWMDMAConfiguration {
        assert(threshold >= 0 && threshold < (1 << 8), "threshold out of range")
        return PWMDMAConfiguration(rawValue: UInt32(threshold) << 8)
    }
    
    public static func dataRequestThreshold(_ threshold: Int) -> PWMDMAConfiguration {
        assert(threshold >= 0 && threshold < (1 << 8), "threshold out of range")
        return PWMDMAConfiguration(rawValue: UInt32(threshold))
    }
    
    /// Panic threshold.
    ///
    /// This is an internal method, access is provided through `PWM`.
    internal var panicThreshold: Int {
        get {
            return Int((rawValue >> 8) & UInt32.mask(bits: 8))
        }
        set {
            assert(newValue >= 0 && newValue < (1 << 8), "threshold out of range")
            self = PWMDMAConfiguration(rawValue: rawValue & UInt32.mask(except: 8, offset: 8) | (UInt32(newValue) << 8))
        }
    }
    
    /// Data Request threshold.
    ///
    /// This is an internal method, access is provided through `PWM`.
    internal var dataRequestThreshold: Int {
        get {
            return Int(rawValue & UInt32.mask(bits: 8))
        }
        set {
            assert(newValue >= 0 && newValue < (1 << 8), "threshold out of range")
            self = PWMDMAConfiguration(rawValue: rawValue & UInt32.mask(except: 8) | UInt32(newValue))
        }
    }
    
}

// MARK: Debugging

extension PWMDMAConfiguration : CustomDebugStringConvertible {
    
    public var debugDescription: String {
        var parts: [String] = []
        
        if contains(.enabled) { parts.append(".enabled") }
        parts.append(".panicThreshold(\(panicThreshold))")
        parts.append(".dataRequestThreshold(\(dataRequestThreshold))")
        
        return "[" + parts.joined(separator: ", ") + "]"
    }
    
}
