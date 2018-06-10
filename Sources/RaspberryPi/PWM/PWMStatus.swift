//
//  PWMStatus.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/10/18.
//

/// PWM status register.
///
/// Provides an type conforming to `OptionSet` that allows direct manipulation of the PWM status
/// register as a set of enumerated constants.
///
///     // Clear all errors at once
///     var status: PWMControl = [ .busError, .channel1GapOccurred, .fifoReadError, .fifoWriteError ]
///     pwm.registers.status.pointee = status
///
public struct PWMStatus : OptionSet, Equatable, Hashable {
    
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public static let channel4Transmitting = PWMStatus(rawValue: 1 << 12)
    public static let channel3Transmitting = PWMStatus(rawValue: 1 << 11)
    public static let channel2Transmitting = PWMStatus(rawValue: 1 << 10)
    public static let channel1Transmitting = PWMStatus(rawValue: 1 << 9)
    public static let busError             = PWMStatus(rawValue: 1 << 8)
    public static let channel4GapOccurred  = PWMStatus(rawValue: 1 << 7)
    public static let channel3GapOccurred  = PWMStatus(rawValue: 1 << 6)
    public static let channel2GapOccurred  = PWMStatus(rawValue: 1 << 5)
    public static let channel1GapOccurred  = PWMStatus(rawValue: 1 << 4)
    public static let fifoReadError        = PWMStatus(rawValue: 1 << 3)
    public static let fifoWriteError       = PWMStatus(rawValue: 1 << 2)
    public static let fifoEmpty            = PWMStatus(rawValue: 1 << 1)
    public static let fifoFull             = PWMStatus(rawValue: 1 << 0)
    
}

// MARK: Debugging

extension PWMStatus : CustomDebugStringConvertible {
    
    public var debugDescription: String {
        var parts: [String] = []
        
        if contains(.channel4Transmitting) { parts.append(".channel4Transmitting") }
        if contains(.channel3Transmitting) { parts.append(".channel3Transmitting") }
        if contains(.channel2Transmitting) { parts.append(".channel2Transmitting") }
        if contains(.channel1Transmitting) { parts.append(".channel1Transmitting") }
        if contains(.busError) { parts.append(".busError") }
        if contains(.channel4GapOccurred) { parts.append(".channel4GapOccurred") }
        if contains(.channel3GapOccurred) { parts.append(".channel3GapOccurred") }
        if contains(.channel2GapOccurred) { parts.append(".channel2GapOccurred") }
        if contains(.channel1GapOccurred) { parts.append(".channel1GapOccurred") }
        if contains(.fifoReadError) { parts.append(".fifoReadError") }
        if contains(.fifoWriteError) { parts.append(".fifoWriteError") }
        if contains(.fifoEmpty) { parts.append(".fifoEmpty") }
        if contains(.fifoFull) { parts.append(".fifoFull") }
        
        return "[" + parts.joined(separator: ", ") + "]"
    }
    
}
