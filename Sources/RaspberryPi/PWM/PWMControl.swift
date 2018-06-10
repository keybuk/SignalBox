//
//  PWMControl.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/10/18.
//

/// PWM control register.
///
/// Provides an type conforming to `OptionSet` that allows direct manipulation of the PWM control
/// register as a set of enumerated constants.
///
///     var control: PWMControl = [ .channel1Enable, .channel1UseFifo, .channel1UseMarkspace ]
///     pwm.registers.control.pointee = control
///
public struct PWMControl : OptionSet, Equatable, Hashable {
    
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public static let channel2UseMarkSpace   = PWMControl(rawValue: 1 << 15)
    public static let channel2UseFifo        = PWMControl(rawValue: 1 << 13)
    public static let channel2InvertPolarity = PWMControl(rawValue: 1 << 12)
    public static let channel2SilenceBit     = PWMControl(rawValue: 1 << 11)
    public static let channel2RepeatLastData = PWMControl(rawValue: 1 << 10)
    public static let channel2SerializerMode = PWMControl(rawValue: 1 << 9)
    public static let channel2Enable         = PWMControl(rawValue: 1 << 8)
    public static let channel1UseMarkSpace   = PWMControl(rawValue: 1 << 7)
    public static let clearFifo              = PWMControl(rawValue: 1 << 6)
    public static let channel1UseFifo        = PWMControl(rawValue: 1 << 5)
    public static let channel1InvertPolarity = PWMControl(rawValue: 1 << 4)
    public static let channel1SilenceBit     = PWMControl(rawValue: 1 << 3)
    public static let channel1RepeatLastData = PWMControl(rawValue: 1 << 2)
    public static let channel1SerializerMode = PWMControl(rawValue: 1 << 1)
    public static let channel1Enable         = PWMControl(rawValue: 1 << 0)
    
}

// MARK: Debugging

extension PWMControl : CustomDebugStringConvertible {
    
    public var debugDescription: String {
        var parts: [String] = []
        
        if contains(.channel2UseMarkSpace) { parts.append(".channel2UseMarkSpace") }
        if contains(.channel2UseFifo) { parts.append(".channel2UseFifo") }
        if contains(.channel2InvertPolarity) { parts.append(".channel2InvertPolarity") }
        if contains(.channel2SilenceBit) { parts.append(".channel2SilenceBit") }
        if contains(.channel2RepeatLastData) { parts.append(".channel2RepeatLastData") }
        if contains(.channel2SerializerMode) { parts.append(".channel2SerializerMode") }
        if contains(.channel2Enable) { parts.append(".channel2Enable") }
        if contains(.channel1UseMarkSpace) { parts.append(".channel1UseMarkSpace") }
        if contains(.clearFifo) { parts.append(".clearFifo") }
        if contains(.channel1UseFifo) { parts.append(".channel1UseFifo") }
        if contains(.channel1InvertPolarity) { parts.append(".channel1InvertPolarity") }
        if contains(.channel1SilenceBit) { parts.append(".channel1SilenceBit") }
        if contains(.channel1RepeatLastData) { parts.append(".channel1RepeatLastData") }
        if contains(.channel1SerializerMode) { parts.append(".channel1SerializerMode") }
        if contains(.channel1Enable) { parts.append(".channel1Enable") }
        
        return "[" + parts.joined(separator: ", ") + "]"
    }
    
}
