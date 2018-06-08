//
//  PWM.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 12/22/16.
//

/// Pulse Width Modulator.
///
/// Instances of `PWM` are used to read and manipulate the underlying pulse width modulator of the
/// Raspberry Pi. All instances manipulate the same hardware, and will differ only in the address
/// of their mapped memory pointer.
///
/// Individual PWM channels are manipulated by subscripting the instance:
///
///     let pwm = try PWM()
///     pwm[1].mode = .serializer
///     pwm[1].useFifo = true
///     pwm[1].isEnabled = true
///
/// While PWM-wide properties are manipulated through the instance directly.
///
///     pwm.addToFifo(0xdeadbeef)
///
/// The instance also conforms to `Collection` so can be iterated to address all channels, as well
/// as other collection and sequence behaviors:
///
///     for channel in pwm {
///         if channel.isEnabled {
///             print("\(channel.number) is \(channel.mode)")
///         }
///     }
///
public final class PWM : MappedPeripheral, Collection {

    /// Offset of the PWM registers from the peripherals base address.
    ///
    /// - Note: BCM2835 Errata
    public static let offset: UInt32 = 0x20c000

    /// PWM registers block.
    ///
    /// - Note: BCM2835 ARM Peripherals 9.6
    public struct Registers {
        public var control: PWMControl
        public var status: PWMStatus
        public var dmaConfiguration: PWMDMAConfiguration
        private var reserved0: UInt32
        public var channel1Range: UInt32
        public var channel1Data: UInt32
        public var fifoInput: UInt32
        private var reserved1: UInt32
        public var channel2Range: UInt32
        public var channel2Data: UInt32

        internal init() {
            control = PWMControl(rawValue: 0)
            status = PWMStatus(rawValue: 0)
            dmaConfiguration = PWMDMAConfiguration(rawValue: 0)
            reserved0 = 0
            channel1Range = 0
            channel1Data = 0
            fifoInput = 0
            reserved1 = 0
            channel2Range = 0
            channel2Data = 0
        }
    }

    /// Pointer to the mapped PWM registers.
    public var registers: UnsafeMutablePointer<Registers>

    /// Unmap `registers` on deinitialization.
    private var unmapOnDeinit: Bool

    /// Number of PWM channels defined by the Raspberry Pi.
    ///
    /// This is accessible through the instance's `count` member, via `Collection` conformance.
    private static let count = 2

    public var startIndex: Int { return 1 }
    public var endIndex: Int { return 1 + PWM.count }
    public func index(after i: Int) -> Int { return i + 1 }
    public subscript(index: Int) -> PWMChannel { return PWMChannel(pwm: self, number: index) }

    public init() throws {
        let memoryDevice = try MemoryDevice()

        registers = try memoryDevice.map(address: PWM.address)
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
            try MemoryDevice.unmap(registers)
        } catch {
            print("Error on PWM deinitialization: \(error)")
        }
    }

    /// Bus error occurred.
    ///
    /// - Note:
    ///   Setting the value to false actually writes 1 to the underlying bit; the interface is
    ///   intended to be more programatic than the underlying hardware register.
    public var isBusError: Bool {
        get { return registers.pointee.status.contains(.busError) }

        set {
            if !newValue {
                registers.pointee.status.insert(.busError)
            }
        }
    }

    // MARK: FIFO

    /// Write to FIFO.
    ///
    /// The FIFO is used instead of `data` when `useFifo` is `true`. It can be written to
    /// multiple times, as long as `isFifoFull` is `false`.
    ///
    /// The FIFO is used for all PWM channels that are enabled to use it; if multiple PWM
    /// channels are using the FIFO, writes must be interleaved. `PWM` does not handle that
    /// for you.
    public func addToFifo(_ value: UInt32) {
        registers.pointee.fifoInput = value
    }

    /// Clear FIFO.
    ///
    /// The FIFO is cleared for all PWM channels that are enabled to use it.
    public func clearFifo() {
        registers.pointee.control.insert(.clearFifo)
    }

    /// Fifo is empty.
    ///
    /// This status applies to all channels.
    public var isFifoEmpty: Bool {
        get { return registers.pointee.status.contains(.fifoEmpty) }
    }

    /// Fifo was read when empty.
    ///
    /// This status applies to all channels.
    ///
    /// - Note:
    ///   Setting the value to false actually writes 1 to the underlying bit; the interface is
    ///   intended to be more programatic than the underlying hardware register.
    public var isFifoReadWhenEmpty: Bool {
        get { return registers.pointee.status.contains(.fifoReadError) }

        set {
            if !newValue {
                registers.pointee.status.insert(.fifoReadError)
            }
        }
    }

    /// Fifo is full.
    ///
    /// This status applies to all channels.
    public var isFifoFull: Bool {
        get { return registers.pointee.status.contains(.fifoFull) }
    }

    /// Fifo was written to when full.
    ///
    /// This status applies to all channels.
    ///
    /// - Note:
    ///   Setting the value to false actually writes 1 to the underlying bit; the interface is
    ///   intended to be more programatic than the underlying hardware register.
    public var isFifoWrittenWhenFull: Bool {
        get { return registers.pointee.status.contains(.fifoWriteError) }

        set {
            if !newValue {
                registers.pointee.status.insert(.fifoWriteError)
            }
        }
    }

    // MARK: DMA configuration

    /// DMA is enabled.
    ///
    /// This setting is shared between all PWM channels.
    public var isDMAEnabled: Bool {
        get { return registers.pointee.dmaConfiguration.contains(.enabled) }
        set {
            if newValue {
                registers.pointee.dmaConfiguration.insert(.enabled)
            } else {
                registers.pointee.dmaConfiguration.remove(.enabled)
            }
        }
    }

    /// Panic threshold.
    ///
    /// When the number of data bits remaining reaches this threshold, the panic signal
    /// is set.
    ///
    /// This setting is shared between all PWM channels.
    public var panicThreshold: Int {
        get { return registers.pointee.dmaConfiguration.panicThreshold }
        set { registers.pointee.dmaConfiguration.panicThreshold = newValue }
    }

    /// DREQ threshold.
    ///
    /// When the number of data bits remaining reaches this threshold, the DREQ signal
    /// is set.
    ///
    /// This setting is shared between all PWM channels.
    public var dreqThreshold: Int {
        get { return registers.pointee.dmaConfiguration.dreqThreshold }
        set { registers.pointee.dmaConfiguration.dreqThreshold = newValue }
    }

}

/// PWM mode.
public enum PWMMode {

    case pwm
    case markSpace
    case serializer

}

/// PWM bit.
public enum PWMBit {

    case low
    case high

}

extension PWM : CustomDebugStringConvertible {

    public var debugDescription: String {
        return "<\(type(of: self)) control: \(registers.pointee.control), status: \(registers.pointee.status)>"
    }

}

/// PWM control register.
///
/// Provides an type conforming to `OptionSet` that allows direct manipulation of the PWM control
/// register as a set of enumerated constants.
///
///     var control: PWMControl = [ .channel1Enable, .channel1UseFifo, .channel1UseMarkspace ]
///     pwm.registers.control.pointee = control
///
public struct PWMControl : OptionSet {

    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let channel2UseMarkSpace   = PWMControl(rawValue: 1 << 15)
    public static let channel2UseFifo        = PWMControl(rawValue: 1 << 13)
    public static let channel2InvertPolarity = PWMControl(rawValue: 1 << 12)
    public static let channel2SilenceBit     = PWMControl(rawValue: 1 << 11)
    public static let channel2RepeatLastData = PWMControl(rawValue: 1 << 10)
    public static let channel2SerializerMode = PWMControl(rawValue: 1 << 9)
    public static let channel2Enable         = PWMControl(rawValue: 1 << 8)
    public static let channel1UseMarkSpace   = PWMControl(rawValue: 1 << 7)
    public static let clearFifo              = PWMControl(rawValue: 1 << 6)
    public static let channel1UseFifo        = PWMControl(rawValue: 1 << 5)
    public static let channel1InvertPolarity = PWMControl(rawValue: 1 << 4)
    public static let channel1SilenceBit     = PWMControl(rawValue: 1 << 3)
    public static let channel1RepeatLastData = PWMControl(rawValue: 1 << 2)
    public static let channel1SerializerMode = PWMControl(rawValue: 1 << 1)
    public static let channel1Enable         = PWMControl(rawValue: 1 << 0)

}

extension PWMControl : CustomDebugStringConvertible {

    public var debugDescription: String {
        var parts: [String] = []

        if contains(.channel2UseMarkSpace) { parts.append(".channel2UseMarkSpace") }
        if contains(.channel2UseFifo) { parts.append(".channel2UseFifo") }
        if contains(.channel2InvertPolarity) { parts.append(".channel2InvertPolarity") }
        if contains(.channel2SilenceBit) { parts.append(".channel2SilenceBit") }
        if contains(.channel2RepeatLastData) { parts.append(".channel2RepeatLastData") }
        if contains(.channel2SerializerMode) { parts.append(".channel2SerializerMode") }
        if contains(.channel2Enable) { parts.append(".channel2Enable") }
        if contains(.channel1UseMarkSpace) { parts.append(".channel1UseMarkSpace") }
        if contains(.clearFifo) { parts.append(".clearFifo") }
        if contains(.channel1UseFifo) { parts.append(".channel1UseFifo") }
        if contains(.channel1InvertPolarity) { parts.append(".channel1InvertPolarity") }
        if contains(.channel1SilenceBit) { parts.append(".channel1SilenceBit") }
        if contains(.channel1RepeatLastData) { parts.append(".channel1RepeatLastData") }
        if contains(.channel1SerializerMode) { parts.append(".channel1SerializerMode") }
        if contains(.channel1Enable) { parts.append(".channel1Enable") }

        return "[" + parts.joined(separator: ", ") + "]"
    }

}

/// PWM status register.
///
/// Provides an type conforming to `OptionSet` that allows direct manipulation of the PWM status
/// register as a set of enumerated constants.
///
///     // Clear all errors at once
///     var status: PWMControl = [ .busError, .channel1GapOccurred, .fifoReadError, .fifoWriteError ]
///     pwm.registers.status.pointee = status
///
public struct PWMStatus : OptionSet {

    public let rawValue: UInt32

    public init(rawValue: UInt32) {
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

extension PWMStatus : CustomDebugStringConvertible {

    public var debugDescription: String {
        var parts: [String] = []

        if contains(.channel4Transmitting) { parts.append(".channel4Transmitting") }
        if contains(.channel3Transmitting) { parts.append(".channel3Transmitting") }
        if contains(.channel2Transmitting) { parts.append(".channel2Transmitting") }
        if contains(.channel1Transmitting) { parts.append(".channel1Transmitting") }
        if contains(.busError) { parts.append(".busError") }
        if contains(.channel4GapOccurred) { parts.append(".channel4GapOccurred") }
        if contains(.channel3GapOccurred) { parts.append(".channel3GapOccurred") }
        if contains(.channel2GapOccurred) { parts.append(".channel2GapOccurred") }
        if contains(.channel1GapOccurred) { parts.append(".channel1GapOccurred") }
        if contains(.fifoReadError) { parts.append(".fifoReadError") }
        if contains(.fifoWriteError) { parts.append(".fifoWriteError") }
        if contains(.fifoEmpty) { parts.append(".fifoEmpty") }
        if contains(.fifoFull) { parts.append(".fifoFull") }

        return "[" + parts.joined(separator: ", ") + "]"
    }

}

/// PWM DMA configuration register.
///
/// Provides an type conforming to `OptionSet` that allows direct manipulation of the PWM DMA
/// configuration registers as a set of enumerated constants.
///
///     var config: PWMDMAConfiguration = [ .enabled, .panicThreshold(15)., dreqThreshold(15) ]
///     pwm.registers.dmaConfiguration.pointee = config
///
public struct PWMDMAConfiguration : OptionSet {

    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let enabled = PWMDMAConfiguration(rawValue: 1 << 31)

    public static func panicThreshold(_ threshold: Int) -> PWMDMAConfiguration {
        assert(threshold < (1 << 8), "threshold out of range")
        return PWMDMAConfiguration(rawValue: UInt32(threshold) << 8)
    }

    public static func dreqThreshold(_ threshold: Int) -> PWMDMAConfiguration {
        assert(threshold < (1 << 8), "threshold out of range")
        return PWMDMAConfiguration(rawValue: UInt32(threshold))
    }

    /// Panic threshold.
    ///
    /// This is an internal method, access is provided through `PWM`.
    internal var panicThreshold: Int {
        get {
            return Int((rawValue >> 8) & UInt32.mask(bits: 8))
        }
        set {
            assert(newValue < (1 << 8), "value out of range")
            self = PWMDMAConfiguration(rawValue: rawValue & UInt32.mask(except: 8, offset: 8) | (UInt32(newValue) << 8))
        }
    }

    /// DREQ threshold.
    ///
    /// This is an internal method, access is provided through `PWM`.
    internal var dreqThreshold: Int {
        get {
            return Int(rawValue & UInt32.mask(bits: 8))
        }
        set {
            assert(newValue < (1 << 8), "value out of range")
            self = PWMDMAConfiguration(rawValue: rawValue & UInt32.mask(except: 8) | UInt32(newValue))
        }
    }

}

extension PWMDMAConfiguration : CustomDebugStringConvertible {

    public var debugDescription: String {
        var parts: [String] = []

        if contains(.enabled) { parts.append(".enabled") }
        parts.append(".panicThreshold(\(panicThreshold))")
        parts.append(".dreqThreshold(\(dreqThreshold))")

        return "[" + parts.joined(separator: ", ") + "]"
    }

}

/// PWM Channel
///
/// Instances of this class are vended by `PWM` and combine the reference to the vending `pwm`
/// instance, and the channel `number`.
public final class PWMChannel {

    /// PWM instance.
    public let pwm: PWM

    /// Channel number.
    public let number: Int

    internal init(pwm: PWM, number: Int) {
        self.pwm = pwm
        self.number = number
    }

    /// PWM channel enabled.
    public var isEnabled: Bool {
        get {
            switch number {
            case 1: return pwm.registers.pointee.control.contains(.channel1Enable)
            case 2: return pwm.registers.pointee.control.contains(.channel2Enable)
            default: preconditionFailure("invalid channel")
            }
        }

        set {
            let enable: PWMControl
            switch number {
            case 1: enable = .channel1Enable
            case 2: enable = .channel2Enable
            default: preconditionFailure("invalid channel")
            }

            if newValue {
                pwm.registers.pointee.control.insert(enable)
            } else {
                pwm.registers.pointee.control.remove(enable)
            }
        }
    }

    /// PWM channel mode.
    ///
    /// Chooses the mode of the PWM channel, selecting the behavior of the `range` and `data`
    /// for the channel.
    ///
    /// Encapsulates both the MODEx and MSENx fields of the control register.
    public var mode: PWMMode {
        get {
            let serializerMode: PWMControl, useMarkspace: PWMControl
            switch number {
            case 1: (serializerMode, useMarkspace) = (.channel1SerializerMode, .channel1UseMarkSpace)
            case 2: (serializerMode, useMarkspace) = (.channel2SerializerMode, .channel2UseMarkSpace)
            default: preconditionFailure("invalid channel")
            }

            switch (pwm.registers.pointee.control.contains(serializerMode), pwm.registers.pointee.control.contains(useMarkspace)) {
            case (true, _): return .serializer
            case (false, true): return .markSpace
            case (false, false): return .pwm
            }
        }

        set {
            let serializerMode: PWMControl, useMarkspace: PWMControl
            switch number {
            case 1: (serializerMode, useMarkspace) = (.channel1SerializerMode, .channel1UseMarkSpace)
            case 2: (serializerMode, useMarkspace) = (.channel2SerializerMode, .channel2UseMarkSpace)
            default: preconditionFailure("invalid channel")
            }

            var control = pwm.registers.pointee.control
            switch newValue {
            case .pwm:
                control.remove(serializerMode)
                control.remove(useMarkspace)
            case .markSpace:
                control.remove(serializerMode)
                control.insert(useMarkspace)
            case .serializer:
                control.insert(serializerMode)
                control.remove(useMarkspace)
            }
            pwm.registers.pointee.control = control
        }
    }

    /// Range of channel.
    ///
    /// The behavior of the range depends on the `mode` of the PWM, and works with the value in
    /// `data` of from the FIRO.
    ///
    /// In PWM mode the range and data define a ratio of time, the output will be high during
    /// the `range` portion and low during the remainder of `data`. Durations are as short as
    /// possible.
    ///
    /// In Mark-space mode `range` bits of one cycle each will be output high, while the
    /// remainder of `data` bits will be output low.
    ///
    /// In Serialiser mode `range` defines the number of bits of `data` that will be transmitted,
    /// with the high or low state determined by `data`. In this mode ranges over a value of 32
    /// result in padding zeros at the end of data.
    public var range: UInt32 {
        get {
            switch number {
            case 1: return pwm.registers.pointee.channel1Range
            case 2: return pwm.registers.pointee.channel2Range
            default: preconditionFailure("invalid channel")
            }
        }
        set {
            switch number {
            case 1: pwm.registers.pointee.channel1Range = newValue
            case 2: pwm.registers.pointee.channel2Range = newValue
            default: preconditionFailure("invalid channel")
            }
        }
    }

    /// Channel data.
    ///
    /// The behavior of channel data depends on the `mode` of the PWM, and works with the value in
    /// `range`. In addition, data is unused when `useFifo` is `true`.
    ///
    /// In PWM mode `data` defines the total duration of a pulse as a ratio compared to `range`.
    ///
    /// In Mark-space mode `data` defines the total duration of a pulse as a number of bits.
    ///
    /// In Serialiser mode `data` defines the actual bits output, limited to `range` bits.
    public var data: UInt32 {
        get {
            switch number {
            case 1: return pwm.registers.pointee.channel1Data
            case 2: return pwm.registers.pointee.channel2Data
            default: preconditionFailure("invalid channel")

            }
        }
        set {
            switch number {
            case 1: pwm.registers.pointee.channel1Data = newValue
            case 2: pwm.registers.pointee.channel2Data = newValue
            default: preconditionFailure("invalid channel")
            }
        }
    }

    /// Channel silence bit.
    ///
    /// Selects the state of the channel when there is no data to transmit, or when padding
    /// data in serializer mode.
    public var silenceBit: PWMBit {
        get {
            let silenceBit: PWMControl
            switch number {
            case 1: silenceBit = .channel1SilenceBit
            case 2: silenceBit = .channel2SilenceBit
            default: preconditionFailure("invalid channel")
            }

            return pwm.registers.pointee.control.contains(silenceBit) ? .high : .low
        }

        set {
            let silenceBit: PWMControl
            switch number {
            case 1: silenceBit = .channel1SilenceBit
            case 2: silenceBit = .channel2SilenceBit
            default: preconditionFailure("invalid channel")
            }

            switch newValue {
            case .high: pwm.registers.pointee.control.insert(silenceBit)
            case .low: pwm.registers.pointee.control.remove(silenceBit)
            }
        }
    }

    /// Channel output polarity is inverted.
    ///
    /// When `true` the channel will output high for a 0, and low for a 1.
    public var invertPolarity: Bool {
        get {
            switch number {
            case 1: return pwm.registers.pointee.control.contains(.channel1InvertPolarity)
            case 2: return pwm.registers.pointee.control.contains(.channel2InvertPolarity)
            default: preconditionFailure("invalid channel")
            }
        }

        set {
            let invertPolarity: PWMControl
            switch number {
            case 1: invertPolarity = .channel1InvertPolarity
            case 2: invertPolarity = .channel2InvertPolarity
            default: preconditionFailure("invalid channel")
            }

            if newValue {
                pwm.registers.pointee.control.insert(invertPolarity)
            } else {
                pwm.registers.pointee.control.remove(invertPolarity)
            }
        }
    }

    // MARK: Channel-specific state

    /// Channel is transmitting.
    ///
    /// - Note:
    ///   Setting the value to false actually writes 1 to the underlying bit; the interface is
    ///   intended to be more programatic than the underlying hardware register.
    public var isTransmitting: Bool {
        get {
            switch number {
            case 1: return pwm.registers.pointee.status.contains(.channel1Transmitting)
            case 2: return pwm.registers.pointee.status.contains(.channel2Transmitting)
            default: preconditionFailure("invalid channel")
            }
        }
    }

    /// Gap occurred during transmission.
    ///
    /// - Note:
    ///   Setting the value to false actually writes 1 to the underlying bit; the interface is
    ///   intended to be more programatic than the underlying hardware register.
    public var isTransmissionGap: Bool {
        get {
            switch number {
            case 1: return pwm.registers.pointee.status.contains(.channel1GapOccurred)
            case 2: return pwm.registers.pointee.status.contains(.channel2GapOccurred)
            default: preconditionFailure("invalid channel")
            }
        }

        set {
            if !newValue {
                switch number {
                case 1: pwm.registers.pointee.status.insert(.channel1GapOccurred)
                case 2: pwm.registers.pointee.status.insert(.channel2GapOccurred)
                default: preconditionFailure("invalid channel")
                }
            }
        }
    }

    /// Channel uses FIFO.
    ///
    /// When `true` the channel will use data written to `fifoInput` rather than `data`.
    public var useFifo: Bool {
        get {
            switch number {
            case 1: return pwm.registers.pointee.control.contains(.channel1UseFifo)
            case 2: return pwm.registers.pointee.control.contains(.channel2UseFifo)
            default: preconditionFailure("invalid channel")
            }
        }

        set {
            let useFifo: PWMControl
            switch number {
            case 1: useFifo = .channel1UseFifo
            case 2: useFifo = .channel2UseFifo
            default: preconditionFailure("invalid channel")
            }

            if newValue {
                pwm.registers.pointee.control.insert(useFifo)
            } else {
                pwm.registers.pointee.control.remove(useFifo)
            }
        }
    }

    /// Channel repeats FIFO data.
    ///
    /// When `true`, if the FIFO becomes empty, the last data written to it is repeated rather
    /// than `silenceBit` being output. Has no effect when `useFifo` is `false`.
    public var repeatFifoData: Bool {
        get {
            switch number {
            case 1: return pwm.registers.pointee.control.contains(.channel1RepeatLastData)
            case 2: return pwm.registers.pointee.control.contains(.channel2RepeatLastData)
            default: preconditionFailure("invalid channel")
            }
        }

        set {
            let repeatLastData: PWMControl
            switch number {
            case 1: repeatLastData = .channel1RepeatLastData
            case 2: repeatLastData = .channel2RepeatLastData
            default: preconditionFailure("invalid channel")
            }

            if newValue {
                pwm.registers.pointee.control.insert(repeatLastData)
            } else {
                pwm.registers.pointee.control.remove(repeatLastData)
            }
        }
    }

}

extension PWMChannel : CustomDebugStringConvertible {

    public var debugDescription: String {
        return "<\(type(of: self)) mode: \(mode), range: \(range), data: \(data)>"
    }

}
