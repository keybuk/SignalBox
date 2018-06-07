//
//  Clock.swift
//  DCC
//
//  Created by Scott James Remnant on 12/22/16.
//

import Util

/// General Purpose, Audio, PCM, and PWM Clocks.
///
/// Instances of `Clock` are used to read and manipulate the underlying clock generators of the
/// Raspberry Pi. All instances with the same `identifier` manipulate the same hardware, and will
/// differ only in the address of their mapped memory pointer.
///
/// A reference to a clock is initialized with the specific clock identifier, and them manipulated
/// through the instance:
///
///     let clock = try Clock(clock: .pcm)
///     // Disable and wait
///     clock.isEnabled = false
///     while clock.isRunning {}
///     // Adjust settings
///     clock.source = .plla
///     clock.mash = .oneStage
///     clock.divisor = ClockDivisor(upperBound: 23.725)
///     // Enable and wait
///     clock.isEnabled = true
///     while !clock.isRunning {}
///
public final class Clock : MappedRegisters {

    /// Clock generator identifier.
    public let identifier: ClockIdentifier

    /// Offset of the Clock registers from the peripherals base address.
    ///
    /// - Note: BCM2835 ARM Peripherals 6.3
    public let registersOffset: UInt32 = 0x101000

    /// Offset of specific clocks from the base `registersOffset`.
    ///
    /// - Note: BCM2835 ARM Peripherals 6.3 and BCM2835 ARM Audio Clocks 1.2
    private let clockOffsets: [ClockIdentifier: UInt32] = [
        .generalPurpose0: 0x70,
        .generalPurpose1: 0x78,
        .generalPurpose2: 0x80,
        .pcm: 0x98,
        .pwm: 0xa0
    ]

    /// Offset of the Clock registers from the peripherals base address.
    public var offset: UInt32 {
        return registersOffset + clockOffsets[identifier]!
    }

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

    /// Pointer to the mapped GPIO registers.
    public var registers: UnsafeMutablePointer<Registers>!
    
    /// Unmap `registers` on deinitialization.
    private var unmapOnDeinit: Bool

    public init(clock identifier: ClockIdentifier) throws {
        self.identifier = identifier
        self.unmapOnDeinit = true
        try mapMemory()
    }

    // For testing.
    internal init(clock identifier: ClockIdentifier, registers: UnsafeMutablePointer<Registers>) {
        self.identifier = identifier
        self.unmapOnDeinit = false
        self.registers = registers
    }

    deinit {
        guard unmapOnDeinit else { return }
        guard registers != nil else { return }
        do {
            try unmapMemory()
        } catch {
            print("Error on Clock deinitialization: \(error)")
        }
    }

    /// Timing source.
    public var source: ClockSource {
        get { return registers.pointee.control.source }
        set { registers.pointee.control.source = newValue }
    }

    /// Clock generator is enabled.
    ///
    /// When this is set, it will not take effect immediately but at the next clock cycle. Check
    /// the value of `isRunning` to once the clock generator has changed.
    public var isEnabled: Bool {
        get { return registers.pointee.control.contains(.enabled) }
        set {
            if newValue {
                registers.pointee.control.insert(.enabled)
            } else {
                registers.pointee.control.remove(.enabled)
            }
        }
    }

    /// Clock generator is running.
    ///
    /// To avoid glitches, `source`, `mash`, and `divisor` should not be changed while this is
    /// `true`.
    public var isRunning: Bool {
        return registers.pointee.control.contains(.busy)
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
        get { return registers.pointee.control.mash }
        set { registers.pointee.control.mash = newValue }
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
        get { return registers.pointee.divisor }
        set { registers.pointee.divisor = newValue }
    }

}

public enum ClockIdentifier {

    case generalPurpose0
    case generalPurpose1
    case generalPurpose2

    case pcm
    case pwm

    public static var allCases: [ClockIdentifier] = [.generalPurpose0, .generalPurpose1, .generalPurpose2, .pcm, .pwm]

}

extension Clock : CustomDebugStringConvertible {

    public var debugDescription: String {
        return "<\(type(of: self)) \(identifier), control: \(registers.pointee.control), divisor: \(divisor)>"
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
