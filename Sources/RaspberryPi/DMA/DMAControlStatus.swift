//
//  DMAControlStatus.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/9/18.
//

import Util

/// DMA control status register.
///
/// Provides a type conforming to `OptionSet` that allows direct manipulation of the DMA control
/// status register as a set of enumerated constants.
///
///     var control: DMAControlStatus = [ .disableDebugPause, .waitForOutstandingWrites, .active ]
///     dma.registers[5].pointee.controlStatus = control
///
public struct DMAControlStatus : OptionSet, Equatable, Hashable {
    
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public static let reset                       = DMAControlStatus(rawValue: 1 << 31)
    public static let abort                       = DMAControlStatus(rawValue: 1 << 30)
    public static let disableDebugPause           = DMAControlStatus(rawValue: 1 << 29)
    public static let waitForOutstandingWrites    = DMAControlStatus(rawValue: 1 << 28)
    public static let errorDetected               = DMAControlStatus(rawValue: 1 << 8)
    public static let waitingForOutstandingWrites = DMAControlStatus(rawValue: 1 << 6)
    public static let pausedByDataRequest         = DMAControlStatus(rawValue: 1 << 5)
    public static let paused                      = DMAControlStatus(rawValue: 1 << 4)
    public static let requestingData              = DMAControlStatus(rawValue: 1 << 3)
    public static let interruptRaised             = DMAControlStatus(rawValue: 1 << 2)
    public static let complete                    = DMAControlStatus(rawValue: 1 << 1)
    public static let active                      = DMAControlStatus(rawValue: 1 << 0)
    
    public static func panicPriorityLevel(_ level: Int) -> DMAControlStatus {
        assert(level < (1 << 4), "level out of range")
        return DMAControlStatus(rawValue: UInt32(level) << 20)
    }
    
    public static func priorityLevel(_ level: Int) -> DMAControlStatus {
        assert(level < (1 << 4), "level out of range")
        return DMAControlStatus(rawValue: UInt32(level) << 16)
    }
    
    /// Panic priority level.
    ///
    /// This is an internal method, access is provided through `DMAChannel`.
    internal var panicPriorityLevel: Int {
        get {
            return Int((rawValue >> 20) & UInt32.mask(bits: 4))
        }
        set {
            assert(newValue < (1 << 4), "value out of range")
            self = DMAControlStatus(rawValue: rawValue & UInt32.mask(except: 4, offset: 20) | (UInt32(newValue) << 20))
        }
    }
    
    /// Priority level.
    ///
    /// This is an internal method, access is provided through `DMAChannel`.
    internal var priorityLevel: Int {
        get {
            return Int((rawValue >> 16) & UInt32.mask(bits: 4))
        }
        set {
            assert(newValue < (1 << 4), "value out of range")
            self = DMAControlStatus(rawValue: rawValue & UInt32.mask(except: 4, offset: 16) | (UInt32(newValue) << 16))
        }
    }
    
}

// MARK: Debugging

extension DMAControlStatus : CustomDebugStringConvertible {
    
    public var debugDescription: String {
        var parts: [String] = []
        
        if contains(.reset) { parts.append(".reset") }
        if contains(.abort) { parts.append(".abort") }
        if contains(.disableDebugPause) { parts.append(".disableDebugPause") }
        if contains(.waitForOutstandingWrites) { parts.append(".waitForOutstandingWrites") }
        if panicPriorityLevel > 0 { parts.append(".panicPriorityLevel(\(panicPriorityLevel))") }
        if priorityLevel > 0 { parts.append(".priorityLevel(\(priorityLevel))") }
        if contains(.errorDetected) { parts.append(".errorDetected") }
        if contains(.waitingForOutstandingWrites) { parts.append(".waitingForOutstandingWrites") }
        if contains(.pausedByDataRequest) { parts.append(".pausedByDataRequest") }
        if contains(.paused) { parts.append(".paused") }
        if contains(.requestingData) { parts.append(".requestingData") }
        if contains(.interruptRaised) { parts.append(".interruptRaised") }
        if contains(.complete) { parts.append(".complete") }
        if contains(.active) { parts.append(".active") }
        
        return "[" + parts.joined(separator: ", ") + "]"
    }
    
}
