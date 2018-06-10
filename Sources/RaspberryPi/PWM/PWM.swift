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
            control = PWMControl()
            status = PWMStatus()
            dmaConfiguration = PWMDMAConfiguration()
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

    /// Fifo was read when empty.
    ///
    /// This status applies to all channels.
    ///
    /// - Note:
    ///   Setting the value to false actually writes 1 to the underlying bit; the interface is
    ///   intended to be more programatic than the underlying hardware register.
    public var isFifoReadError: Bool {
        get { return registers.pointee.status.contains(.fifoReadError) }

        set {
            if !newValue {
                registers.pointee.status.insert(.fifoReadError)
            }
        }
    }

    /// Fifo was written to when full.
    ///
    /// This status applies to all channels.
    ///
    /// - Note:
    ///   Setting the value to false actually writes 1 to the underlying bit; the interface is
    ///   intended to be more programatic than the underlying hardware register.
    public var isFifoWriteError: Bool {
        get { return registers.pointee.status.contains(.fifoWriteError) }
        
        set {
            if !newValue {
                registers.pointee.status.insert(.fifoWriteError)
            }
        }
    }
    
    /// Fifo is empty.
    ///
    /// This status applies to all channels.
    public var isFifoEmpty: Bool {
        get { return registers.pointee.status.contains(.fifoEmpty) }
    }
    
    /// Fifo is full.
    ///
    /// This status applies to all channels.
    public var isFifoFull: Bool {
        get { return registers.pointee.status.contains(.fifoFull) }
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

    /// Data Request threshold.
    ///
    /// When the number of data bits remaining reaches this threshold, the DREQ signal
    /// is set.
    ///
    /// This setting is shared between all PWM channels.
    public var dataRequestThreshold: Int {
        get { return registers.pointee.dmaConfiguration.dataRequestThreshold }
        set { registers.pointee.dmaConfiguration.dataRequestThreshold = newValue }
    }

}

// MARK: Debugging

extension PWM : CustomDebugStringConvertible {
    
    public var debugDescription: String {
        var parts: [String] = []
        
        parts.append("\(type(of: self)) control: \(registers.pointee.control)")
        parts.append("status: \(registers.pointee.status)")
        
        return "<" + parts.joined(separator: ", ") + ">"
    }
    
}
