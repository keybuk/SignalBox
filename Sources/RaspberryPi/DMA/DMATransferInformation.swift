//
//  DMATransferInformation.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/9/18.
//

import Util

/// DMA transfer information.
///
/// Provides a type conforming to `OptionSet` that allows direct manipulation of the DMA transfer
/// information field in a `DMAControlBlock`, and the equivalent register, as a set of enumerated
/// constants.
///
///     var transferInfo: DMATransferInformation = [
///         .peripheral(.pwm),
///         .incrementSourceAddress,
///         .destinationWaitsForDataRequest,
///         .waitForWriteResponse
///     ]
///     controlBlock.transferInformation = transferInfo
///
public struct DMATransferInformation : OptionSet, Equatable, Hashable {
    
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public static let noWideBursts                   = DMATransferInformation(rawValue: 1 << 26)
    public static let sourceIgnoreReads              = DMATransferInformation(rawValue: 1 << 11)
    public static let sourceWaitsForDataRequest      = DMATransferInformation(rawValue: 1 << 10)
    public static let sourceWideReads                = DMATransferInformation(rawValue: 1 << 9)
    public static let incrementSourceAddress         = DMATransferInformation(rawValue: 1 << 8)
    public static let destinationIgnoreWrites        = DMATransferInformation(rawValue: 1 << 7)
    public static let destinationWaitsForDataRequest = DMATransferInformation(rawValue: 1 << 6)
    public static let destinationWideWrites          = DMATransferInformation(rawValue: 1 << 5)
    public static let incrementDestinationAddress    = DMATransferInformation(rawValue: 1 << 4)
    public static let waitForWriteResponse           = DMATransferInformation(rawValue: 1 << 3)
    public static let tdMode                         = DMATransferInformation(rawValue: 1 << 1)
    public static let raiseInterrupt                 = DMATransferInformation(rawValue: 1 << 0)
    
    public static func waitCycles(_ cycles: Int) -> DMATransferInformation {
        assert(cycles >= 0 && cycles < (1 << 5), "cycles out of range")
        return DMATransferInformation(rawValue: UInt32(cycles) << 21)
    }
    
    public static func peripheral(_ peripheral: DMAPeripheral) -> DMATransferInformation {
        return DMATransferInformation(rawValue: UInt32(peripheral.rawValue) << 16)
    }
    
    public static func burstTransferLength(_ length: Int) -> DMATransferInformation {
        assert(length >= 0 && length < (1 << 4), "length out of range")
        return DMATransferInformation(rawValue: UInt32(length) << 12)
    }
    
    /// Wait cycles.
    ///
    /// This is an internal method, access is provided through `DMAChannel`.
    internal var waitCycles: Int {
        get {
            return Int((rawValue >> 21) & UInt32.mask(bits: 5))
        }
        set {
            assert(newValue >= 0 && newValue < (1 << 5), "cycles out of range")
            self = DMATransferInformation(rawValue: rawValue & UInt32.mask(except: 5, offset: 21) | (UInt32(newValue) << 21))
        }
    }
    
    /// Peripheral mapping.
    ///
    /// This is an internal method, access is provided through `DMAChannel`.
    internal var peripheral: DMAPeripheral {
        get {
            return DMAPeripheral(rawValue: Int((rawValue >> 16) & UInt32.mask(bits: 5)))!
        }
        set {
            self = DMATransferInformation(rawValue: rawValue & UInt32.mask(except: 5, offset: 16) | (UInt32(newValue.rawValue) << 16))
        }
    }
    
    /// Burst transfer length.
    ///
    /// This is an internal method, access is provided through `DMAChannel`.
    internal var burstTransferLength: Int {
        get {
            return Int((rawValue >> 12) & UInt32.mask(bits: 4))
        }
        set {
            assert(newValue >= 0 && newValue < (1 << 4), "length out of range")
            self = DMATransferInformation(rawValue: rawValue & UInt32.mask(except: 4, offset: 12) | (UInt32(newValue) << 12))
        }
    }
    
}

// MARK: Debugging

extension DMATransferInformation : CustomDebugStringConvertible {
    
    public var debugDescription: String {
        var parts: [String] = []
        
        if contains(.noWideBursts) { parts.append(".noWideBursts") }
        if waitCycles > 0 { parts.append(".waitCycles(\(waitCycles))") }
        if peripheral != .none { parts.append(".peripheral(.\(peripheral))") }
        if burstTransferLength > 0 { parts.append(".burstTransferLength(\(burstTransferLength))") }
        if contains(.sourceIgnoreReads) { parts.append(".sourceIgnoreReads") }
        if contains(.sourceWaitsForDataRequest) { parts.append(".sourceWaitsForDataRequest") }
        if contains(.sourceWideReads) { parts.append(".sourceWideReads") }
        if contains(.incrementSourceAddress) { parts.append(".incrementSourceAddress") }
        if contains(.destinationIgnoreWrites) { parts.append(".destinationIgnoreWrites") }
        if contains(.destinationWaitsForDataRequest) { parts.append(".destinationWaitsForDataRequest") }
        if contains(.destinationWideWrites) { parts.append(".destinationWideWrites") }
        if contains(.incrementDestinationAddress) { parts.append(".incrementDestinationAddress") }
        if contains(.waitForWriteResponse) { parts.append(".waitForWriteResponse") }
        if contains(.tdMode) { parts.append(".tdMode") }
        if contains(.raiseInterrupt) { parts.append(".raiseInterrupt") }
        
        return "[" + parts.joined(separator: ", ") + "]"
    }
    
}
