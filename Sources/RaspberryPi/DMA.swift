//
//  DMA.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/21/16.
//
//

#if os(Linux)
import Glibc
#else
import Darwin
#endif


public struct DMAControlStatus : OptionSet, CustomStringConvertible {
    
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let reset                       = DMAControlStatus(rawValue: 1 << 31)
    public static let abort                       = DMAControlStatus(rawValue: 1 << 30)
    public static let disableDebugPauseSignal     = DMAControlStatus(rawValue: 1 << 29)
    public static let waitForOutstandingWrites    = DMAControlStatus(rawValue: 1 << 28)
    public static let errorDetected               = DMAControlStatus(rawValue: 1 << 8)
    public static let waitingForOutstandingWrites = DMAControlStatus(rawValue: 1 << 6)
    public static let pausedByDREQ                = DMAControlStatus(rawValue: 1 << 5)
    public static let paused                      = DMAControlStatus(rawValue: 1 << 4)
    public static let requestingData              = DMAControlStatus(rawValue: 1 << 3)
    public static let interrupted                 = DMAControlStatus(rawValue: 1 << 2)
    public static let transferComplete            = DMAControlStatus(rawValue: 1 << 1)
    public static let active                      = DMAControlStatus(rawValue: 1 << 0)

    public static func panicPriorityLevel(_ level: Int) -> DMAControlStatus {
        assert(level < (1 << 4), ".panicPriorityLevel limited to 4 bits")
        return DMAControlStatus(rawValue: level << 20)
    }
    
    public var panicPriorityLevel: Int {
        return (rawValue >> 20) & ((1 << 4) - 1)
    }

    public static func priorityLevel(_ level: Int) -> DMAControlStatus {
        assert(level < (1 << 4), ".priorityLevel limited to 4 bits")
        return DMAControlStatus(rawValue: level << 16)
    }
    
    public var priorityLevel: Int {
        return (rawValue >> 16) & ((1 << 4) - 1)
    }
    
    public var description: String {
        var parts: [String] = []

        if contains(.reset) { parts.append(".reset") }
        if contains(.abort) { parts.append(".abort") }
        if contains(.disableDebugPauseSignal) { parts.append(".disableDebugPauseSignal") }
        if contains(.waitForOutstandingWrites) { parts.append(".waitForOutstandingWrites") }
        if contains(.errorDetected) { parts.append(".errorDetected") }
        if contains(.waitingForOutstandingWrites) { parts.append(".waitingForOutstandingWrites") }
        if contains(.pausedByDREQ) { parts.append(".pausedByDREQ") }
        if contains(.paused) { parts.append(".paused") }
        if contains(.requestingData) { parts.append(".requestingData") }
        if contains(.interrupted) { parts.append(".interrupted") }
        if contains(.transferComplete) { parts.append(".transferComplete") }
        if contains(.active) { parts.append(".active") }

        if priorityLevel > 0 {
            parts.append(".priorityLevel(\(priorityLevel))")
        }

        if panicPriorityLevel > 0 {
            parts.append(".panicPriorityLevel(\(panicPriorityLevel))")
        }

        return "[" + parts.joined(separator: ", ") + "]"
    }

}

public enum DMAPeripheral : Int {
    
    case none        = 0
    case dsi         = 1
    case pcmTx       = 2
    case pcmRx       = 3
    case smi         = 4
    case pwm         = 5
    case spiTx       = 6
    case spiRx       = 7
    case bscTx       = 8
    case bscRx       = 9
    case eMMC        = 11
    case uartTx      = 12
    case sdHost      = 13
    case uartRx      = 14
    case dsi_1       = 15
    case slimbusMCTX = 16
    case hdmi        = 17
    case slimbusMCRC = 18
    case slimbusDC0  = 19
    case slimbusDC1  = 20
    case slimbusDC2  = 21
    case slimbusDC3  = 22
    case slimbusDC4  = 23
    case scalerFIFO0 = 24
    case scalerFIFO1 = 25
    case scalerFIFO2 = 26
    case slimbusDC5  = 27
    case slimbusDC6  = 28
    case slimbusDC7  = 29
    case slimbusDC8  = 30
    case slimbusDC9  = 31

}

public struct DMATransferInformation : OptionSet, CustomStringConvertible {
    
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let noWideBursts                = DMATransferInformation(rawValue: 1 << 26)
    public static let sourceIgnoreReads           = DMATransferInformation(rawValue: 1 << 11)
    public static let sourceDREQ                  = DMATransferInformation(rawValue: 1 << 10)
    public static let sourceWidthWide             = DMATransferInformation(rawValue: 1 << 9)
    public static let sourceAddressIncrement      = DMATransferInformation(rawValue: 1 << 8)
    public static let destinationIgnoreWrites     = DMATransferInformation(rawValue: 1 << 7)
    public static let destinationDREQ             = DMATransferInformation(rawValue: 1 << 6)
    public static let destinationWidthWide        = DMATransferInformation(rawValue: 1 << 5)
    public static let destinationAddressIncrement = DMATransferInformation(rawValue: 1 << 4)
    public static let waitForWriteResponse        = DMATransferInformation(rawValue: 1 << 3)
    public static let tdMode                      = DMATransferInformation(rawValue: 1 << 1)
    public static let interruptEnable             = DMATransferInformation(rawValue: 1 << 0)
    
    public static func waitCycles(_ cycles: Int) -> DMATransferInformation {
        assert(cycles < (1 << 5), ".waitCycles limited to 5 bits")
        return DMATransferInformation(rawValue: cycles << 21)
    }
    
    public var waitCycles: Int {
        return (rawValue >> 21) & ((1 << 5) - 1)
    }
    
    public static func peripheralMapping(_ peripheral: DMAPeripheral) -> DMATransferInformation {
        assert(peripheral.rawValue < (1 << 5), ".peripheralMapping limited to 5 bits")
        return DMATransferInformation(rawValue: peripheral.rawValue << 16)
    }
    
    public var peripheralMapping: DMAPeripheral? {
        return DMAPeripheral(rawValue: (rawValue >> 16) & ((1 << 5) - 1))
    }
        
    public static func burstTransferLength(_ length: Int) -> DMATransferInformation {
        assert(length < (1 << 4), ".burstTransferLength limited to 4 bits")
        return DMATransferInformation(rawValue: length << 12)
    }

    public var burstTransferLength: Int {
        return (rawValue >> 12) & ((1 << 4) - 1)
    }
    
    public var description: String {
        var parts: [String] = []
        
        if contains(.noWideBursts) { parts.append(".noWideBursts") }
        if contains(.sourceIgnoreReads) { parts.append(".sourceIgnoreReads") }
        if contains(.sourceDREQ) { parts.append(".sourceDREQ") }
        if contains(.sourceWidthWide) { parts.append(".sourceWidthWide") }
        if contains(.sourceAddressIncrement) { parts.append(".sourceAddressIncrement") }
        if contains(.destinationIgnoreWrites) { parts.append(".destinationIgnoreWrites") }
        if contains(.destinationDREQ) { parts.append(".destinationDREQ") }
        if contains(.destinationWidthWide) { parts.append(".destinationWidthWide") }
        if contains(.destinationAddressIncrement) { parts.append(".destinationAddressIncrement") }
        if contains(.waitForWriteResponse) { parts.append(".waitForWriteResponse") }
        if contains(.tdMode) { parts.append(".tdMode") }
        if contains(.interruptEnable) { parts.append(".interruptEnable") }
        
        if waitCycles > 0 {
            parts.append(".waitCycles(\(waitCycles))")
        }
        
        if let peripheralMapping = peripheralMapping,
            peripheralMapping != .none
        {
            parts.append(".peripheralMapping(.\(peripheralMapping))")
        }
        
        if burstTransferLength > 0 {
            parts.append(".burstTransferLength(\(burstTransferLength))")
        }
        
        return "[" + parts.joined(separator: ", ") + "]"
    }
    
}

public struct DMADebug : OptionSet, CustomStringConvertible {
    
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let isLite              = DMADebug(rawValue: 1 << 28)
    public static let readError           = DMADebug(rawValue: 1 << 2)
    public static let fifoError           = DMADebug(rawValue: 1 << 1)
    public static let readLastNotSetError = DMADebug(rawValue: 1 << 0)
    
    public static func version(_ version: Int) -> DMADebug {
        assert(version < (1 << 3), ".version limited to 3 bits")
        return DMADebug(rawValue: version << 25)
    }
    
    public var version: Int {
        return (rawValue >> 25) & ((1 << 3) - 1)
    }

    public static func axiIdentifier(_ identifier: Int) -> DMADebug {
        assert(identifier < (1 << 8), ".axiIdentifier limited to 8 bits")
        return DMADebug(rawValue: identifier << 8)
    }
    
    public var axiIdentifier: Int {
        return (rawValue >> 8) & ((1 << 8) - 1)
    }
    
    public static func stateMachineState(_ state: Int) -> DMADebug {
        assert(state < (1 << 9), ".stateMachineState limited to 9 bits")
        return DMADebug(rawValue: state << 16)
    }
    
    public var stateMachineState: Int {
        return (rawValue >> 16) & ((1 << 9) - 1)
    }

    public static func numberOfOutstandingWrites(_ count: Int) -> DMADebug {
        assert(count < (1 << 4), ".numberOfOutstandingWrites limited to 4 bits")
        return DMADebug(rawValue: count << 4)
    }
    
    public var numberOfOutstandingWrites: Int {
        return (rawValue >> 4) & ((1 << 4) - 1)
    }
    
    public var description: String {
        var parts: [String] = []
        
        if contains(.isLite) { parts.append(".isLite") }
        
        parts.append(".version(\(version))")
        parts.append(".axiIdentifier(\(axiIdentifier))")
        parts.append(".stateMachineState(\(stateMachineState))")
        parts.append(".numberOfOutstandingWrites(\(numberOfOutstandingWrites))")
        
        if contains(.readError) { parts.append(".readError") }
        if contains(.fifoError) { parts.append(".fifoError") }
        if contains(.readLastNotSetError) { parts.append(".readLastNotSetError") }

        return "[" + parts.joined(separator: ", ") + "]"
    }
    
}


public struct DMAControlBlock : Equatable {
    
    public var transferInformation: DMATransferInformation
    public var sourceAddress: Int
    public var destinationAddress: Int
    public var transferLength: Int
    public var tdModeStride: Int
    public var nextControlBlockAddress: Int
    private var reserved0: Int
    private var reserved1: Int
    
    public static let transferInformationOffset = 0x00
    public static let sourceAddressOffset       = 0x04
    public static let destinationAddressOffset  = 0x08
    public static let transferLengthOffset      = 0x0c
    public static let tdModeStrideOffset        = 0x10
    public static let nextControlBlockOffset    = 0x14
    
    public static let stopAddress = 0x00000000
    
    public init(transferInformation: DMATransferInformation, sourceAddress: Int, destinationAddress: Int, transferLength: Int, tdModeStride: Int, nextControlBlockAddress: Int) {
        self.transferInformation = transferInformation
        self.sourceAddress = sourceAddress
        self.destinationAddress = destinationAddress
        self.transferLength = transferLength
        self.tdModeStride = tdModeStride
        self.nextControlBlockAddress = nextControlBlockAddress
        
        self.reserved0 = 0
        self.reserved1 = 0
    }
    
    public static func tdTransferLength(x: Int, y: Int) -> Int {
        return (x << 0) | (y << 16)
    }
    
    public static func tdModeStride(source: Int, destination: Int) -> Int {
        return (source << 0) | (destination << 16)
    }
    
    public static func ==(lhs: DMAControlBlock, rhs: DMAControlBlock) -> Bool {
        return lhs.transferInformation == rhs.transferInformation && lhs.sourceAddress == rhs.sourceAddress && lhs.destinationAddress == rhs.destinationAddress && lhs.transferLength == rhs.transferLength && lhs.tdModeStride == rhs.tdModeStride && lhs.nextControlBlockAddress == rhs.nextControlBlockAddress
    }
    
}

public struct DMAChannel {
    
    let number: Int

    struct Registers {
        var controlStatus: DMAControlStatus
        var controlBlockAddress: Int
        var transferInformation: DMATransferInformation
        var sourceAddress: Int
        var destinationAddress: Int
        var transferLength: Int
        var tdModeStride: Int
        var nextControlBlockAddress: Int
        var debug: DMADebug
    }
    
    let registers: UnsafeMutablePointer<Registers>
    let interruptStatusRegister: UnsafeMutablePointer<Int>
    let enableRegister: UnsafeMutablePointer<Int>

    public static let controlStatusOffset       = 0x00
    public static let controlBlockAddressOffset = 0x04
    public static let debugOffset               = 0x20

    public var controlStatus: DMAControlStatus {
        get { return registers.pointee.controlStatus }
        set { registers.pointee.controlStatus = newValue }
    }
    
    public var controlBlockAddress: Int {
        get { return registers.pointee.controlBlockAddress }
        set { registers.pointee.controlBlockAddress = newValue }
    }
    
    public var transferInformation: DMATransferInformation {
        get { return registers.pointee.transferInformation }
    }

    public var sourceAddress: Int {
        get { return registers.pointee.sourceAddress }
    }
    
    public var destinationAddress: Int {
        get { return registers.pointee.destinationAddress }
    }
    
    public var transferLength: Int {
        get { return registers.pointee.transferLength }
    }
    
    // 2D transfer length
    
    public var tdModeStride: Int {
        get { return registers.pointee.tdModeStride }
    }
    
    // 2D mode stride split
    
    public var nextControlBlockAddress: Int {
        get { return registers.pointee.nextControlBlockAddress }
    }
    
    public var debug: DMADebug {
        get { return registers.pointee.debug }
        set { registers.pointee.debug = newValue }
    }
    
    public var enabled: Bool {
        get { return (enableRegister.pointee & (1 << number)) != 0 }
        set {
            if newValue {
                enableRegister.pointee |= (1 << number)
            } else {
                enableRegister.pointee &= ~(1 << number)
            }
        }
    }
    
    public var interruptStatus: Bool {
        get { return (interruptStatusRegister.pointee & (1 << number)) != 0 }
    }
    
    init(channel number: Int, peripherals: UnsafeMutableRawPointer) {
        self.number = number

        registers = peripherals.advanced(by: DMA.offset + DMA.channelStride * number).bindMemory(to: Registers.self, capacity: 1)
        interruptStatusRegister = peripherals.advanced(by: DMA.offset + DMA.interruptStatusOffset).bindMemory(to: Int.self, capacity: 1)
        enableRegister = peripherals.advanced(by: DMA.offset + DMA.enableOffset).bindMemory(to: Int.self, capacity: 1)
    }
    
}

public enum DMA {

    static let count = 16
    
    static let offset                = 0x007000
    static let size                  = 0x001000
    static let channel15Offset       = 0xe05000
    static let channel15Size         = 0x000100
    
    static let channelStride         = 0x100
    static let interruptStatusOffset = 0xfe0
    static let enableOffset          = 0xff0
    
}
