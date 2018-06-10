//
//  GPIO.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 12/20/16.
//
//

/// General Purpose I/O (GPIO)
///
/// Instances of `GPIO` are used to read and manipulate the underlying GPIO hardware of the
/// Raspberry Pi. All instances manipulate the same hardware, and will differ only in the address
/// of their mapped memory pointer.
///
/// Individual GPIO pins are manipulated by subscripting the instance:
///
///     let gpio = try GPIO()
///     gpio[17].function = .output
///     gpio[17].value = true
///
/// The instance also conforms to `Collection` so can be iterated to address all pins, as well
/// as other collection and sequence behaviors:
///
///     for pin in gpio {
///         if pin.function == .input {
///             print("\(pin.number) = \(pin.value)")
///         }
///     }
///
public final class GPIO : MappedPeripheral, Collection {

    /// Offset of the GPIO registers from the peripherals base address.
    ///
    /// - Note: BCM2835 ARM Peripherals 6.1
    public static let offset: UInt32 = 0x200000

    /// GPIO registers block.
    ///
    /// - Note: BCM2835 ARM Peripherals 6.1
    public struct Registers {
        public var functionSelect: GPIOFunctionSelect
        public var outputSet: GPIOBitField
        public var outputClear: GPIOBitField
        public var level: GPIOBitField
        public var eventDetectStatus: GPIOBitField
        public var risingEdgeDetectEnable: GPIOBitField
        public var fallingEdgeDetectEnable: GPIOBitField
        public var highDetectEnable: GPIOBitField
        public var lowDetectEnable: GPIOBitField
        public var asyncRisingEdgeDetectEnable: GPIOBitField
        public var asyncFallingEdgeDetectEnable: GPIOBitField
        public var pullUpDownEnable: UInt32
        public var pullUpDownEnableClock: GPIOBitField

        // For testing.
        internal init() {
            functionSelect = GPIOFunctionSelect()
            outputSet = GPIOBitField()
            outputClear = GPIOBitField()
            level = GPIOBitField()
            eventDetectStatus = GPIOBitField()
            risingEdgeDetectEnable = GPIOBitField()
            fallingEdgeDetectEnable = GPIOBitField()
            highDetectEnable = GPIOBitField()
            lowDetectEnable = GPIOBitField()
            asyncRisingEdgeDetectEnable = GPIOBitField()
            asyncFallingEdgeDetectEnable = GPIOBitField()
            pullUpDownEnable = 0
            pullUpDownEnableClock = GPIOBitField()
        }
    }

    /// Pointer to the mapped GPIO registers.
    public var registers: UnsafeMutablePointer<Registers>

    /// Unmap `registers` on deinitialization.
    private var unmapOnDeinit: Bool

    /// Number of GPIO registers defined by the Raspberry Pi.
    ///
    /// This is accessible through the instance's `count` member, via `Collection` conformance.
    private static let count = 54

    public var startIndex: Int { return 0 }
    public var endIndex: Int { return GPIO.count }
    public func index(after i: Int) -> Int { return i + 1 }
    public subscript(index: Int) -> GPIOPin { return GPIOPin(gpio: self, number: index) }

    public init() throws {
        let memoryDevice = try MemoryDevice()

        registers = try memoryDevice.map(address: GPIO.address)
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
            print("Error on GPIO deinitialization: \(error)")
        }
    }

    /// Pull-up/down enable.
    ///
    /// Controls the actuation of the internal pull-up/down control line to all of the GPIO pins.
    /// Due to limitations of the hardware registers, reading from this property always returns
    /// `.disabled`.
    ///
    /// - Note:
    ///   This only controls the actuation of the clock, for the full sequence necessary to set
    ///   a GPIO pin, see BCM2835 ARM Peripherals 6.1 for details, example:
    ///
    ///       gpio.pullUpDownEnable = .pullUp
    ///       usleep(150) // 1MHz
    ///       gpio[17].pullUpDownClock = true
    ///       usleep(150)
    ///       gpio.pullUpDownEnable = .disabled
    ///       gpio[17].pullUpDownClock = false
    ///
    public var pullUpDownEnable: GPIOPullUpDown {
        get { return .disabled }
        set { registers.pointee.pullUpDownEnable = newValue.rawValue }
    }

}
