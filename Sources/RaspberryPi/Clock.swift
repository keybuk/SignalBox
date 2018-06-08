//
//  Clock.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 12/22/16.
//

import Util

/// General Purpose, Audio, PCM, and PWM Clocks.
///
/// Instances of `Clocks` are used to read and manipulate the underlying clock generators of the
/// Raspberry Pi. All instances manipulate the same hardware, and will differ only in the address
/// of their mapped memory pointer.
///
/// Individual clock generators are manipulated by subscripting the instance:
///
///     let clock = try Clocks()
///     // Disable and wait
///     clock[.pcm].isEnabled = false
///     while clock[.pcm].isRunning {}
///     // Adjust settings
///     clock[.pcm].source = .plla
///     clock[.pcm].mash = .oneStage
///     clock[.pcm].divisor = ClockDivisor(upperBound: 23.725)
///     // Enable and wait
///     clock[.pcm].isEnabled = true
///     while !clock[.pcm].isRunning {}
///
public final class Clocks : MappedRegisters, Collection {

    /// Offset of the Clock registers from the peripherals base address.
    ///
    /// - Note: BCM2835 ARM Peripherals 6.3
    public static let offset: UInt32 = 0x101000

    /// Number of Clock registers defined by the Raspberry Pi.
    ///
    /// This is not the number of available clocks, but the size of the registers space. Access
    /// the number of clocks through the instance's `count`
    internal static let registerCount = 22

    /// Clock generator registers block.
    ///
    /// - Note: BCM2835 ARM Peripherals 6.3
    public struct Registers {
        public var control: ClockControl
        public var divisor: ClockDivisor

        // For testing.
        internal init() {
            control = []
            divisor = ClockDivisor(rawValue: 0)
        }
    }

    /// Pointer to the mapped clock registers.
    public var registers: UnsafeMutablePointer<Registers>

    /// Unmap `registers` on deinitialization.
    private var unmapOnDeinit: Bool

    public var startIndex: ClockIdentifier { return ClockIdentifier.startIndex }
    public var endIndex: ClockIdentifier { return ClockIdentifier.endIndex }
    public func index(after i: ClockIdentifier) -> ClockIdentifier { return ClockIdentifier.index(after: i) }
    public subscript(index: ClockIdentifier) -> Clock {
        return Clock(clocks: self, identifier: index)
    }

    public init() throws {
        let memoryDevice = try MemoryDevice()

        registers = try memoryDevice.map(address: Clocks.address, count: Clocks.registerCount)
        unmapOnDeinit = true
    }

    // For testing.
    internal init(registers: UnsafeMutablePointer<Registers>) {
        unmapOnDeinit = false
        self.registers = registers
    }

    deinit {
        guard unmapOnDeinit else { return }
        do {
            try MemoryDevice.unmap(registers, count: Clocks.registerCount)
        } catch {
            print("Error on Clock deinitialization: \(error)")
        }
    }

}

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
        return registerOffset / MemoryLayout<Clocks.Registers>.stride
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

/// Clock control register.
///
/// Provides an type conforming to `OptionSet` that allows direct manipulation of a clock control
/// register as a set of enumerated constants.
///
///     var control: ClockControl = [ .source(.pwm), .mash(.none), .enabled ]
///     clock.registers.control.pointee = control
///
public struct ClockControl : OptionSet {

    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = 0x5a000000 | rawValue
    }

    public static let invertOutput = ClockControl(rawValue: 1 << 8)
    public static let busy         = ClockControl(rawValue: 1 << 7)
    public static let kill         = ClockControl(rawValue: 1 << 5)
    public static let enabled      = ClockControl(rawValue: 1 << 4)

    public static func mash(_ mash: ClockMASH) -> ClockControl {
        return ClockControl(rawValue: mash.rawValue << 9)
    }

    public static func source(_ source: ClockSource) -> ClockControl {
        return ClockControl(rawValue: source.rawValue)
    }

    /// Timing source.
    ///
    /// This is an internal method, access is provided through `Clock`.
    internal var source: ClockSource {
        get {
            return ClockSource(rawValue: rawValue & UInt32.mask(bits: 4)) ?? .none
        }
        set {
            self = ClockControl(rawValue: rawValue & UInt32.mask(except: 4) | newValue.rawValue)
        }
    }

    /// Noise-shaping MASH filter.
    ///
    /// This is an internal method, access is provided through `Clock`.
    internal var mash: ClockMASH {
        get {
            return ClockMASH(rawValue: (rawValue >> 9) & UInt32.mask(bits: 2))!
        }
        set {
            self = ClockControl(rawValue: rawValue & UInt32.mask(except: 2, offset: 9) | (newValue.rawValue << 9))
        }
    }

}

extension ClockControl : CustomDebugStringConvertible {

    public var debugDescription: String {
        var parts: [String] = []

        parts.append(".source(.\(source))")
        parts.append(".mash(.\(mash))")

        if contains(.invertOutput) { parts.append(".invertOutput") }
        if contains(.busy) { parts.append(".busy") }
        if contains(.kill) { parts.append(".kill") }
        if contains(.enabled) { parts.append(".enabled") }

        return "[" + parts.joined(separator: ", ") + "]"
    }

}

/// Clock MASH filter options.
public enum ClockMASH : UInt32 {

    case integer    = 0
    case oneStage   = 1
    case twoStage   = 2
    case threeStage = 3

}

/// Clock sources.
public enum ClockSource : UInt32 {

    case none       = 0
    case oscillator = 1
    case testDebug0 = 2
    case testDebug1 = 3
    case plla       = 4
    case pllc       = 5
    case plld       = 6
    case hdmiAux    = 7

}

/// Clock divisor register.
///
/// Provides an type that encapsulates the clock divisor register, permitted values to be
/// initialized from integer or fractional components:
///
///     let divisor = ClockDivisor(integer: 82, fractional: 503)
///
/// Or by providing a float value to use as an upper bound:
///
///     let divisor = ClockDivisor(upperBound: 82.123)
///
/// The `integer` and `fractional` parts can be manipulated directly, and the value can be
/// assigned to `Clock.divisor`:
///
///     clock.divisor = ClockDivisor(upperBoard: 91.5)
///
public struct ClockDivisor : RawRepresentable {

    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = 0x5a000000 | rawValue
    }

    public init(integer: Int, fractional: Int) {
        assert(integer < 4096, "integer out of range")
        assert(fractional < 4096, "fractional out of range")
        self.init(rawValue: (UInt32(clamping: integer) << 12) | UInt32(clamping: fractional))
    }

    public init<T: BinaryFloatingPoint>(upperBound value: T) {
        assert(value >= 0 && value < 4096, "value out of range")
        self.init(integer: Int(value), fractional: Int(4096 * (value - value.rounded(.towardZero)))
)
    }

    /// Divisor integer component.
    ///
    /// The value must be less than 4096.
    public var integer: Int {
        get {
            return Int(clamping: (rawValue >> 12) & UInt32.mask(bits: 12))
        }
        set {
            assert(newValue < (1 << 12), "value out of range")
            self = ClockDivisor(rawValue: rawValue & UInt32.mask(except: 12, offset: 12) | (UInt32(clamping: newValue) << 12))
        }
    }

    /// Divisor fractional component.
    ///
    /// The value is used as a fraction of 4096, for example 2048 represents 0.5.
    ///
    /// The value must be less than 4096.
    public var fractional: Int {
        get {
            return Int(clamping: rawValue & UInt32.mask(bits: 12))
        }
        set {
            assert(newValue < (1 << 12), "value out of range")
            self = ClockDivisor(rawValue: rawValue & UInt32.mask(except: 12) | UInt32(clamping: newValue))
        }
    }

}

extension ClockDivisor : CustomStringConvertible {

    public var description: String {
        let floatValue = Float(integer) + Float(fractional) / 4096
        return "\(floatValue)"
    }

}

/// Single clock generator.
///
/// Instances of this class are vended by `Clock` and combine the reference to the vending `clock`
/// instance, and the specific clock `identifier`.
public final class Clock {

    /// Clocks instance.
    public let clocks: Clocks

    /// Clock identifier.
    public let identifier: ClockIdentifier

    public init(clocks: Clocks, identifier: ClockIdentifier) {
        self.clocks = clocks
        self.identifier = identifier
    }

    /// Timing source.
    public var source: ClockSource {
        get { return clocks.registers[identifier.registerIndex].control.source }
        set { clocks.registers[identifier.registerIndex].control.source = newValue }
    }

    /// Clock generator is enabled.
    ///
    /// When this is set, it will not take effect immediately but at the next clock cycle. Check
    /// the value of `isRunning` to once the clock generator has changed.
    public var isEnabled: Bool {
        get { return clocks.registers[identifier.registerIndex].control.contains(.enabled) }
        set {
            if newValue {
                clocks.registers[identifier.registerIndex].control.insert(.enabled)
            } else {
                clocks.registers[identifier.registerIndex].control.remove(.enabled)
            }
        }
    }

    /// Clock generator is running.
    ///
    /// To avoid glitches, `source`, `mash`, and `divisor` should not be changed while this is
    /// `true`.
    public var isRunning: Bool {
        return clocks.registers[identifier.registerIndex].control.contains(.busy)
    }

    /// Noise-shaping MASH filter.
    ///
    /// The average frequency of the generated clock will match the frequency of the source,
    /// divided by `divisor`. This is achieved by dropping or waiting additional ticks, above and
    /// below the intended frequency, in order to reach it.
    ///
    /// The amount of filter applied is adjusted by this setting.
    ///
    /// To avoid glitches, do not change while `isRunning` is `true`.
    public var mash: ClockMASH {
        get { return clocks.registers[identifier.registerIndex].control.mash }
        set { clocks.registers[identifier.registerIndex].control.mash = newValue }
    }

    /// Frequency divisor.
    ///
    /// Sets the average frequency of the generated clock as a division of the frequency of the
    /// source clock.
    ///
    /// The divisor consists of two parts, an integer and a fractional part; the easiest way to
    /// initialize is to give a float for the upper bound, but they can be provided directly:
    ///
    ///     let divisor = ClockDivisor(upperBound: 82.123)
    ///     // Equivalent to:
    ///     let divisor = ClockDivisor(integer: 82, fractional: 503)
    ///
    /// The divisor must be less than 4096.
    ///
    /// To avoid glitches, do not change while `isRunning` is `true`.
    public var divisor: ClockDivisor {
        get { return clocks.registers[identifier.registerIndex].divisor }
        set { clocks.registers[identifier.registerIndex].divisor = newValue }
    }

}

extension Clock : CustomDebugStringConvertible {

    public var debugDescription: String {
        return "<\(type(of: self)) \(identifier), control: \(clocks.registers[identifier.registerIndex].control), divisor: \(divisor)>"
    }

}

