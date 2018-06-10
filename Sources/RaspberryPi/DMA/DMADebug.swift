//
//  DMADebug.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/9/18.
//

import Util

/// DMA debug register.
///
/// Provides a type conforming to `OptionSet` that allows direct manipulation of the DMA debug
/// register as a set of enumerated constants.
///
///     // Clear all errors in one write.
///     var debug: DMADebug = [ .readError, .fifoError, .readLastNotSetError ]
///     dma.registers[5].pointee.debug = debug
///
public struct DMADebug : OptionSet, Equatable, Hashable {
    
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public static let isLite              = DMADebug(rawValue: 1 << 28)
    public static let readError           = DMADebug(rawValue: 1 << 2)
    public static let fifoError           = DMADebug(rawValue: 1 << 1)
    public static let readLastNotSetError = DMADebug(rawValue: 1 << 0)
    
    public static func version(_ version: Int) -> DMADebug {
        assert(version < (1 << 3), "version out of range")
        return DMADebug(rawValue: UInt32(version) << 25)
    }
    
    public static func axiIdentifier(_ identifier: Int) -> DMADebug {
        assert(identifier < (1 << 8), "identifier out of range")
        return DMADebug(rawValue: UInt32(identifier) << 8)
    }
    
    public static func stateMachineState(_ state: Int) -> DMADebug {
        assert(state < (1 << 9), "state out of range")
        return DMADebug(rawValue: UInt32(state) << 16)
    }
    
    public static func numberOfOutstandingWrites(_ count: Int) -> DMADebug {
        assert(count < (1 << 4), "count out of range")
        return DMADebug(rawValue: UInt32(count) << 4)
    }
    
    /// DMA Version.
    ///
    /// This is an internal method, access is provided through `DMAChannel`.
    internal var version: Int {
        return Int((rawValue >> 25) & UInt32.mask(bits: 3))
    }
    
    /// DMA engine's state machine state.
    ///
    /// This is an internal method, access is provided through `DMAChannel`.
    internal var stateMachineState: Int {
        return Int((rawValue >> 16) & UInt32.mask(bits: 8))
    }
    
    /// DMA Version.
    ///
    /// This is an internal method, access is provided through `DMAChannel`.
    internal var axiIdentifier: Int {
        return Int((rawValue >> 8) & UInt32.mask(bits: 8))
    }
    
    /// Number of outstanding writes.
    ///
    /// This is an internal method, access is provided through `DMAChannel`.
    internal var numberOfOutstandingWrites: Int {
        return Int((rawValue >> 4) & UInt32.mask(bits: 4))
    }
    
}

// MARK: Debugging

extension DMADebug : CustomDebugStringConvertible {
    
    public var debugDescription: String {
        var parts: [String] = []
        
        if contains(.isLite) { parts.append(".isLite") }
        
        parts.append(".version(\(version))")
        parts.append(".stateMachineState(\(stateMachineState))")
        parts.append(".axiIdentifier(\(axiIdentifier))")
        parts.append(".numberOfOutstandingWrites(\(numberOfOutstandingWrites))")
        
        if contains(.readError) { parts.append(".readError") }
        if contains(.fifoError) { parts.append(".fifoError") }
        if contains(.readLastNotSetError) { parts.append(".readLastNotSetError") }
        
        return "[" + parts.joined(separator: ", ") + "]"
    }
    
}
