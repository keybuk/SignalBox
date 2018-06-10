//
//  ClockIdentifier.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/10/18.
//

/// Clock generator identifier.
public enum ClockIdentifier : Comparable {
    
    // BCM2835 ARM Peripherals 6.3
    case generalPurpose0
    case generalPurpose1
    case generalPurpose2
    
    // BCM2835 Audio Clocks.
    case pcm
    case pwm
    
    // This exists only to provide ability to conform to `Collection.Index`.
    case invalid
    
    /// Offset of clock-specific registers from the register base.
    ///
    /// - Note: BCM2835 ARM Peripherals 6.3, and BCM2835 Audio Clocks.
    internal var offset: Int {
        switch self {
        case .generalPurpose0: return 0x70
        case .generalPurpose1: return 0x78
        case .generalPurpose2: return 0x80
        case .pcm: return 0x98
        case .pwm: return 0xa0
        default: return 0xff
        }
    }
    
    /// Next identifier in ordered set.
    internal var next: ClockIdentifier {
        switch self {
        case .generalPurpose0: return .generalPurpose1
        case .generalPurpose1: return .generalPurpose2
        case .generalPurpose2: return .pcm
        case .pcm: return .pwm
        case .pwm: return .invalid
        default: preconditionFailure("invalid identifier")
        }
    }
    
    public static func < (lhs: ClockIdentifier, rhs: ClockIdentifier) -> Bool {
        return lhs.offset < rhs.offset
    }
    
}
