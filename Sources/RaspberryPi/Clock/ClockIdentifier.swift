//
//  ClockIdentifier.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/10/18.
//

/// Clock generator identifier.
public enum ClockIdentifier : Comparable {
    
    case generalPurpose0
    case generalPurpose1
    case generalPurpose2
    
    case pcm
    case pwm
    
    case invalid
    
    /// Offset of clock-specific registers from the register base.
    ///
    /// - Note: BCM2835 ARM Peripherals 6.3, and BCM2835 Audio Clocks.
    internal var registerOffset: Int {
        switch self {
        case .generalPurpose0: return 0x70
        case .generalPurpose1: return 0x78
        case .generalPurpose2: return 0x80
        case .pcm: return 0x98
        case .pwm: return 0xa0
        default: return 0xff
        }
    }
    
    /// Index of clock-specific registers within the mapped array.
    ///
    /// Divides the offset taken from the datasheet by the stride of the register structure.
    internal var registerIndex: Int {
        return registerOffset / MemoryLayout<Clock.Registers>.stride
    }
    
    /// Ordered list of clock identifiers.
    ///
    /// Used to allow Clocks to be treated as a collection.
    private static let ordered: [ClockIdentifier] = [
        .generalPurpose0,
        .generalPurpose1,
        .generalPurpose2,
        .pcm,
        .pwm,
        .invalid
    ]
    
    internal static var startIndex: ClockIdentifier { return ordered[ordered.startIndex] }
    internal static var endIndex: ClockIdentifier { return ordered[ordered.endIndex - 1] }
    internal static func index(after i: ClockIdentifier) -> ClockIdentifier {
        return ordered[ordered.index(after: ordered.index(of: i)!)]
    }
    
    public static func < (lhs: ClockIdentifier, rhs: ClockIdentifier) -> Bool {
        return lhs.registerOffset < rhs.registerOffset
    }
    
}
