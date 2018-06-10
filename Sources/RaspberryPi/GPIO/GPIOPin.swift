//
//  GPIOPin.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/10/18.
//

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
    
    internal init(gpio: GPIO, number: Int) {
        assert(number >= 0 && number <= gpio.count, "pin out of range")
        
        self.gpio = gpio
        self.number = number
    }
    
}

// MARK: Debugging

extension GPIOPin : CustomDebugStringConvertible {
    
    public var debugDescription: String {
        var description = "<\(type(of: self)) \(number) \(function) \(value)"
        if edgeDetect != .none { description += ", edgeDetect: \(edgeDetect)" }
        if levelDetect != .none { description += ", levelDetect: \(levelDetect)" }
        if asyncEdgeDetect != .none { description += ", asyncEdgeDetect: \(asyncEdgeDetect)" }
        if isEventDetected { description += ", event" }
        description += ">"
        
        return description
    }
    
}
