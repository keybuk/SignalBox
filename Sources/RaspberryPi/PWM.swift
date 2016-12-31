//
//  PWM.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/22/16.
//
//

public struct PWMControl : OptionSet {

    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let channel2UseMarkspace   = PWMControl(rawValue: 1 << 15)
    public static let channel2UseFifo        = PWMControl(rawValue: 1 << 13)
    public static let channel2InvertPolarity = PWMControl(rawValue: 1 << 12)
    public static let channel2SilenceBit     = PWMControl(rawValue: 1 << 11)
    public static let channel2RepeatLastData = PWMControl(rawValue: 1 << 10)
    public static let channel2SerializerMode = PWMControl(rawValue: 1 << 9)
    public static let channel2Enable         = PWMControl(rawValue: 1 << 8)
    public static let channel1UseMarkspace   = PWMControl(rawValue: 1 << 7)
    public static let clearFifo              = PWMControl(rawValue: 1 << 6)
    public static let channel1UseFifo        = PWMControl(rawValue: 1 << 5)
    public static let channel1InvertPolarity = PWMControl(rawValue: 1 << 4)
    public static let channel1SilenceBit     = PWMControl(rawValue: 1 << 3)
    public static let channel1RepeatLastData = PWMControl(rawValue: 1 << 2)
    public static let channel1SerializerMode = PWMControl(rawValue: 1 << 1)
    public static let channel1Enable         = PWMControl(rawValue: 1 << 0)
    
}

public struct PWMStatus : OptionSet {
    
    public let rawValue: Int
    
    public init(rawValue: Int) {
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

public struct PWMDMAConfiguration : OptionSet {
    
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let enabled = PWMDMAConfiguration(rawValue: 1 << 31)
    
    public static func panicThreshold(_ threshold: Int) -> PWMDMAConfiguration {
        assert(threshold < (1 << 8), ".panicThreshold is limited to 8 bits")
        return PWMDMAConfiguration(rawValue: threshold << 8)
    }
    
    public var panicThreshold: Int {
        return (rawValue >> 8) & ((1 << 8) - 1)
    }
 
    public static func dreqThreshold(_ threshold: Int) -> PWMDMAConfiguration {
        assert(threshold < (1 << 8), ".dreqThreshold is limited to 8 bits")
        return PWMDMAConfiguration(rawValue: threshold << 0)
    }
    
    public var dreqThreshold: Int {
        return (rawValue >> 0) & ((1 << 8) - 1)
    }

}

// FIXME: this is really an internal register map, and not a good public API.
public struct PWM {
    
    public var control: PWMControl
    public var status: PWMStatus
    public var dmaConfiguration: PWMDMAConfiguration
    var reserved0: Int
    public var channel1Range: Int
    public var channel1Data: Int
    public var fifoInput: Int
    var reserved1: Int
    public var channel2Range: Int
    public var channel2Data: Int

    public static let offset = 0x20c000
    public static let size   = 0x00002c

    public static let controlOffset          = 0x00
    public static let statusOffset           = 0x04
    public static let dmaConfigurationOffset = 0x08
    public static let channel1RangeOffset    = 0x10
    public static let channel1DataOffset     = 0x14
    public static let fifoInputOffset        = 0x18
    public static let channel2RangeOffset    = 0x20
    public static let channel2DataOffset     = 0x28
    
    // FIXME: this name is bad, and Swift-style requires the 'On' be inside the '('.
    public static func on(_ raspberryPi: RaspberryPi) throws -> UnsafeMutablePointer<PWM> {
        // FIXME: this memory map gets leaked.
        let pointer = try raspberryPi.mapMemory(at: raspberryPi.peripheralPhysicalAddress + PWM.offset, size: PWM.size)
        return pointer.bindMemory(to: PWM.self, capacity: 1)
    }
    
    public mutating func disable() {
        control.remove([ .channel1Enable, .channel2Enable ])
        dmaConfiguration.remove(.enabled)
    }
    
    public mutating func reset() {
        control = []
        status.insert([ .busError, .fifoReadError, .fifoWriteError, .channel1GapOccurred, .channel2GapOccurred, .channel3GapOccurred, .channel4GapOccurred ])
    }

}
