//
//  Clock.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 12/22/16.
//

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
public final class Clock : MappedPeripheral, Collection {

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
    public subscript(index: ClockIdentifier) -> ClockGenerator {
        return ClockGenerator(clock: self, identifier: index)
    }

    public init() throws {
        let memoryDevice = try MemoryDevice()

        registers = try memoryDevice.map(address: Clock.address, count: Clock.registerCount)
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
            try MemoryDevice.unmap(registers, count: Clock.registerCount)
        } catch {
            print("Error on Clock deinitialization: \(error)")
        }
    }

}
