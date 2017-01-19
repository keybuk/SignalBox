//
//  Clock.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/22/16.
//
//

#if os(Linux)
import Glibc
#else
import Darwin
#endif


public enum ClockMASH : Int {

    case integer    = 0
    case oneStage   = 1
    case twoStage   = 2
    case threeStage = 3

}

public enum ClockSource : Int {

    case none       = 0
    case oscillator = 1
    case testDebug0 = 2
    case testDebug1 = 3
    case plla       = 4
    case pllc       = 5
    case plld       = 6
    case hdmiAux    = 7
    
}

public struct ClockControl : OptionSet, CustomStringConvertible {
    
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = 0x5a000000 | rawValue
    }

    public static let invertOutput = ClockControl(rawValue: 1 << 8)
    public static let busy         = ClockControl(rawValue: 1 << 7)
    public static let killClock    = ClockControl(rawValue: 1 << 5)
    public static let enabled      = ClockControl(rawValue: 1 << 4)
    
    public static func mash(_ mash: ClockMASH) -> ClockControl {
        assert(mash.rawValue < (1 << 2), ".mash limited to 2 bits")
        return ClockControl(rawValue: mash.rawValue << 9)
    }
    
    public var mash: ClockMASH? {
        return ClockMASH(rawValue: (rawValue >> 9) & ((1 << 2) - 1))
    }
    
    public static func source(_ source: ClockSource) -> ClockControl {
        assert(source.rawValue < (1 << 4), ".source limited to 4 bits")
        return ClockControl(rawValue: source.rawValue << 0)
    }
    
    public var source: ClockSource? {
        return ClockSource(rawValue: (rawValue >> 0) & ((1 << 4) - 1))
    }
    
    public var description: String {
        var parts: [String] = []
        
        if let source = source {
            parts.append(".source(.\(source))")
        }
        if let mash = mash {
            parts.append(".mash(.\(mash))")
        }
        
        if contains(.invertOutput) { parts.append(".invertOutput") }
        if contains(.busy) { parts.append(".busy") }
        if contains(.killClock) { parts.append(".killClock") }
        if contains(.enabled) { parts.append(".enabled") }
        
        return "[" + parts.joined(separator: ", ") + "]"
    }

}

public struct ClockDivisor : OptionSet, CustomStringConvertible {

    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = 0x5a000000 | rawValue
    }

    public static func integer(_ divisor: Int) -> ClockDivisor {
        assert(divisor < (1 << 12), ".integer is limited to 12 bits")
        return ClockDivisor(rawValue: divisor << 12)
    }
    
    public var integer: Int {
        return (rawValue >> 12) & ((1 << 12) - 1)
    }
    
    public static func fraction(_ divisor: Int) -> ClockDivisor {
        assert(divisor < (1 << 12), ".fraction is limited to 12 bits")
        return ClockDivisor(rawValue: divisor << 0)
    }

    public var fraction: Int {
        return (rawValue >> 0) & ((1 << 12) - 1)
    }
    
    public var description: String {
        var parts: [String] = []

        parts.append(".integer(\(integer))")
        parts.append(".fraction(\(fraction))")
        
        return "[" + parts.joined(separator: ", ") + "]"
    }
    
}

public enum ClockIdentifier {
    case generalPurpose0
    case generalPurpose1
    case generalPurpose2
    
    case pcm
    case pwm
}

public struct Clock {
    
    let identifier: ClockIdentifier
    
    struct Registers {
        var control: ClockControl
        var divisor: ClockDivisor
    }
    
    let registers: UnsafeMutablePointer<Registers>
    
    public static let offset = 0x101000
    public static let size   = 0x000100
    
    public static let clockSize = 0x000008

    public static let generalPurpose0Offset = 0x70
    public static let generalPurpose1Offset = 0x78
    public static let generalPurpose2Offset = 0x80
    
    public static let pcmOffset             = 0x98
    public static let pwmOffset             = 0xa0

    public static let controlOffset = 0x00
    public static let divisorOffset = 0x04
    
    public var control: ClockControl {
        get { return registers.pointee.control }
        set { registers.pointee.control = newValue }
    }
    
    public var divisor: ClockDivisor {
        get { return registers.pointee.divisor }
        set { registers.pointee.divisor = newValue }
    }
    
    init(identifier: ClockIdentifier, peripherals: UnsafeMutableRawPointer) {
        let offset: Int
        switch identifier {
        case .generalPurpose0:
            offset = Clock.generalPurpose0Offset
        case .generalPurpose1:
            offset = Clock.generalPurpose1Offset
        case .generalPurpose2:
            offset = Clock.generalPurpose2Offset
        case .pcm:
            offset = Clock.pcmOffset
        case .pwm:
            offset = Clock.pwmOffset
        }
        
        self.identifier = identifier
        self.registers = peripherals.advanced(by: Clock.offset + offset).bindMemory(to: Registers.self, capacity: 1)
    }

    public mutating func disable() {
        control.remove(.enabled)
        while control.contains(.busy) { }
    }

    public mutating func enable() {
        control.insert(.enabled)
        while !control.contains(.busy) { }
    }
    
}
