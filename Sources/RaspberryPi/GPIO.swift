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
public final class GPIO : MappedRegisters, Collection {

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
        public var pullUpDownEnable: GPIOPullUpDown
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
            pullUpDownEnable = .disabled
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
        set { registers.pointee.pullUpDownEnable = newValue }
    }

}

/// GPIO function selection registers.
///
/// Represents the block of GPIO Function Select registers, providing subscript access to
/// manipulate the individual GPIO fields within the block.
///
/// The preferred way to manipulate GPIO pin functions is through the `GPIO` class, however it can
/// often be useful to interact with the registers directly, for example when used with DMA, or
/// by making mass changes to the registers by taking a copy.
///
///     // Read setting of GPIO 12 at a point in time.
///     var fsel = gpio.registers.pointee.functionSelect
///     // ...
///     print(fsel[12])
///
///     // Reset all GPIO to input except three.
///     var fsel = GPIOFunctionSelect()
///     fsel[17] = .output
///     fsel[18] = .output
///     fsel[19] = .output
///     gpio.registers.pointee.functionSelect = fsel
///
public struct GPIOFunctionSelect {

    internal var field0: UInt32
    internal var field1: UInt32
    internal var field2: UInt32
    internal var field3: UInt32
    internal var field4: UInt32
    internal var field5: UInt32
    private var reserved: UInt32

    public subscript(index: Int) -> GPIOFunction {
        get {
            let field: UInt32
            switch index / 10 {
            case 0: field = field0
            case 1: field = field1
            case 2: field = field2
            case 3: field = field3
            case 4: field = field4
            case 5: field = field5
            default: preconditionFailure("index out of range")
            }

            let shift = (index % 10) * 3
            let bits = (field >> shift) & 0b111
            return GPIOFunction(rawValue: bits)!
        }

        set {
            let shift = (index % 10) * 3
            let mask: UInt32 = ~(0b111 << shift)
            let bits = newValue.rawValue << shift

            switch index / 10 {
            case 0: field0 = field0 & mask | bits
            case 1: field1 = field1 & mask | bits
            case 2: field2 = field2 & mask | bits
            case 3: field3 = field3 & mask | bits
            case 4: field4 = field4 & mask | bits
            case 5: field5 = field5 & mask | bits
            default: preconditionFailure("index out of range")
            }
        }
    }

    public init() {
        field0 = 0
        field1 = 0
        field2 = 0
        field3 = 0
        field4 = 0
        field5 = 0
        reserved = 0
    }

}

/// GPIO function
///
/// Defines the possible operations of GPIO pins.
public enum GPIOFunction : UInt32 {

    case input              = 0b000
    case output             = 0b001
    case alternateFunction0 = 0b100
    case alternateFunction1 = 0b101
    case alternateFunction2 = 0b110
    case alternateFunction3 = 0b111
    case alternateFunction4 = 0b011
    case alternateFunction5 = 0b010

}

/// GPIO bit fields.
///
/// Represents the block of registers for individual GPIO bit fields, where one bit represents
/// one GPIO. The block includes the reserved field that follows each set of fields. Provides
/// subscript access to manipulate the individual GPIO bits within the block.
///
/// The preferred way to manipulate GPIO pin functions is through the `GPIO` class, however it can
/// often be useful to interact with the registers directly, for example when used with DMA, or
/// by making mass changes to the registers.
///
///     // Set multiple outputs in one write.
///     var outputSet = GPIOBitField()
///     outputSet[17] = true
///     outputSet[18] = true
///     outputSet[19] = true
///     gpio.registers.pointee.outputSet = outputSet
///
public struct GPIOBitField {

    internal var field0: UInt32
    internal var field1: UInt32
    private var reserved: UInt32

    public subscript(index: Int) -> Bool {
        get {
            let field: UInt32
            switch index / 32 {
            case 0: field = field0
            case 1: field = field1
            default: preconditionFailure("index out of range")
            }

            let shift = index % 32
            return field & (1 << shift) != 0
        }

        set {
            let shift = index % 32
            let mask: UInt32 = ~(1 << shift)
            let bits: UInt32 = newValue ? 1 << shift : 0

            switch index / 32 {
            case 0: field0 = field0 & mask | bits
            case 1: field1 = field1 & mask | bits
            default: preconditionFailure("index out of range")
            }
        }
    }

    public init() {
        field0 = 0
        field1 = 0
        reserved = 0
    }

}

/// GPIO pull-up/down enable
///
/// Defines the possible actuations of the internal pull-up/down control line for each GPIO.
public enum GPIOPullUpDown : UInt32 {

    case disabled = 0b00
    case pullDown = 0b01
    case pullUp   = 0b10

}

/// Single GPIO Pin
///
/// Instances of this class are vended by `GPIO` and combine the reference to the vending `gpio`
/// instance, and the pin `number`.
public final class GPIOPin {

    /// GPIO instance.
    public let gpio: GPIO

    /// GPIO pin number.
    public let number: Int

    /// GPIO function selection.
    ///
    /// Defines the operation of the GPIO pin. Each pin can be set as an `input`, in which case the
    /// pin's `value` is defined by the external source, or as an `output` in which case `value`
    /// defines the output of the pin.
    ///
    /// Pins also have at least two alternative functions defined in BCM2835 ARM Peripherals 16.2.
    public var function: GPIOFunction {
        get { return gpio.registers.pointee.functionSelect[number] }
        set { gpio.registers.pointee.functionSelect[number] = newValue }
    }

    /// GPIO pin value.
    ///
    /// Reads or sets the value of the GPIO pin.
    ///
    /// When `value` is read, returns the appropriate GPIO Pin Level bit; when `value` is set to
    /// `true`, writes the appropriate GPIO Pin Output Set bit; when `value` is set to `false`,
    /// writes the appropriate GPIO Pin Output Clear bit.
    public var value: Bool {
        get { return gpio.registers.pointee.level[number] }
        set {
            if newValue {
                gpio.registers.pointee.outputSet[number] = true
            } else {
                gpio.registers.pointee.outputClear[number] = true
            }
        }
    }

    /// Event detection.
    ///
    /// When `value` is read, returns whether level or edge events were detected on the GPIO pin.
    /// When `value` is set to `false`, the event is cleared; setting the `value` to `true` is
    /// ignored.
    ///
    /// - Note:
    ///   Setting the value to false actually writes 1 to the underlying bit; the interface is
    ///   intended to be more programatic than the underlying hardware register.
    public var isEventDetected: Bool {
        get { return gpio.registers.pointee.eventDetectStatus[number] }
        set {
            if !newValue {
                gpio.registers.pointee.eventDetectStatus[number] = true
            }
        }
    }

    /// Edge detection.
    ///
    /// Defines whether this pin detects edge events using synchronous detection, this samples the
    /// pin using the system clock, requiring two samples of the appropriate level to detect an
    /// edge.
    ///
    /// When such an event is detected, `isEventDetected` becomes `true` and can be cleared by
    /// setting that back to `false.
    public var edgeDetect: GPIOEdge {
        get {
            switch (gpio.registers.pointee.risingEdgeDetectEnable[number], gpio.registers.pointee.fallingEdgeDetectEnable[number]) {
            case (false, false): return .none
            case (true, false): return .rising
            case (false, true): return .falling
            case (true, true): return .both
            }
        }

        set {
            let rising: Bool, falling: Bool
            switch newValue {
            case .none: rising = false; falling = false
            case .rising: rising = true; falling = false
            case .falling: rising = false; falling = true
            case .both: rising = true; falling = true
            }

            gpio.registers.pointee.risingEdgeDetectEnable[number] = rising
            gpio.registers.pointee.fallingEdgeDetectEnable[number] = falling
        }
    }

    /// Level detection.
    ///
    /// Defines the levels for which the pin sets `isEventDetected` to `true`. The level can be
    /// cleared by setting that to `false`, however this will have no effect when the pin is still
    /// at the defined level.
    public var levelDetect: GPIOLevel {
        get {
            switch (gpio.registers.pointee.highDetectEnable[number], gpio.registers.pointee.lowDetectEnable[number]) {
            case (false, false): return .none
            case (true, false): return .high
            case (false, true): return .low
            case (true, true): return .both
            }
        }

        set {
            let high: Bool, low: Bool
            switch newValue {
            case .none: high = false; low = false
            case .high: high = true; low = false
            case .low: high = false; low = true
            case .both: high = true; low = true
            }

            gpio.registers.pointee.highDetectEnable[number] = high
            gpio.registers.pointee.lowDetectEnable[number] = low
        }
    }

    /// Asynchronous edge detection.
    ///
    /// Defines whether this pin detects edge events using asynchronous detection, this does not
    /// sample the pin using the system clock, and as such can detect edges of very short duration.
    ///
    /// When such an event is detected, `isEventDetected` becomes `true` and can be cleared by
    /// setting that back to `false.
    public var asyncEdgeDetect: GPIOEdge {
        get {
            switch (gpio.registers.pointee.asyncRisingEdgeDetectEnable[number], gpio.registers.pointee.asyncFallingEdgeDetectEnable[number]) {
            case (false, false): return .none
            case (true, false): return .rising
            case (false, true): return .falling
            case (true, true): return .both
            }
        }

        set {
            let rising: Bool, falling: Bool
            switch newValue {
            case .none: rising = false; falling = false
            case .rising: rising = true; falling = false
            case .falling: rising = false; falling = true
            case .both: rising = true; falling = true
            }

            gpio.registers.pointee.asyncRisingEdgeDetectEnable[number] = rising
            gpio.registers.pointee.asyncFallingEdgeDetectEnable[number] = falling
        }
    }

    /// Pull-up/down clock.
    ///
    /// Controls the actuation of the internal pull-up/down on the GPIO pin.
    ///
    /// - Note:
    ///   This only controls the per-pin control of the clock, for the full sequence necessary to
    ///   set a GPIO pin, see BCM2835 ARM Peripherals 6.1 for details, example:
    ///
    ///       gpio.pullUpDownEnable = .pullUp
    ///       usleep(150) // 1MHz
    ///       gpio[17].pullUpDownClock = true
    ///       usleep(150)
    ///       gpio.pullUpDownEnable = .disabled
    ///       gpio[17].pullUpDownClock = false
    ///
    public var pullUpDownClock: Bool {
        get { return gpio.registers.pointee.pullUpDownEnableClock[number] }
        set { gpio.registers.pointee.pullUpDownEnableClock[number] = newValue }
    }

    fileprivate init(gpio: GPIO, number: Int) {
        assert(number >= 0 && number <= gpio.count, "pin out of range")

        self.gpio = gpio
        self.number = number
    }

}

/// Edge.
///
/// Defines the possible edges that can be detected.
public enum GPIOEdge {

    case none
    case rising
    case falling
    case both

}

/// Level.
///
/// Defines the possible levels that can be detected.
public enum GPIOLevel {

    case none
    case high
    case low
    case both

}

