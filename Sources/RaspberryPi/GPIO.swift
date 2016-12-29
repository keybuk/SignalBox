//
//  GPIO.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/20/16.
//
//

public enum GPIOFunction : Int {

    case input              = 0b000
    case output             = 0b001
    case alternateFunction0 = 0b100
    case alternateFunction1 = 0b101
    case alternateFunction2 = 0b110
    case alternateFunction3 = 0b111
    case alternateFunction4 = 0b011
    case alternateFunction5 = 0b010

}

public struct GPIOFunctionSelect : Collection {

    var field0: Int
    var field1: Int
    var field2: Int
    var field3: Int
    var field4: Int
    var field5: Int
    var reserved: Int

    // These are computed properties, rather than constants, so that they don't take up space in the structure.
    public var startIndex: Int { return 0 }
    public var endIndex: Int { return GPIO.count }

    public func index(after i: Int) -> Int {
        return i + 1
    }

    public subscript(index: Int) -> GPIOFunction {
        get {
            let shift = ((index % 10) * 3)
            switch index / 10 {
            case 0:
                return GPIOFunction(rawValue: (field0 >> shift) & 0b111)!
            case 1:
                return GPIOFunction(rawValue: (field1 >> shift) & 0b111)!
            case 2:
                return GPIOFunction(rawValue: (field2 >> shift) & 0b111)!
            case 3:
                return GPIOFunction(rawValue: (field3 >> shift) & 0b111)!
            case 4:
                return GPIOFunction(rawValue: (field4 >> shift) & 0b111)!
            case 5:
                return GPIOFunction(rawValue: (field5 >> shift) & 0b111)!
            default:
                fatalError("GPIO index out of bounds")
            }
        }
        
        set(newValue) {
            let mask = 0b111 << ((index % 10) * 3)
            let bits = newValue.rawValue << ((index % 10) * 3)
            switch index / 10 {
            case 0:
                let field = field0 & ~mask
                field0 = field | bits
            case 1:
                let field = field1 & ~mask
                field1 = field | bits
            case 2:
                let field = field2 & ~mask
                field2 = field | bits
            case 3:
                let field = field3 & ~mask
                field3 = field | bits
            case 4:
                let field = field4 & ~mask
                field4 = field | bits
            case 5:
                let field = field5 & ~mask
                field5 = field | bits
            default:
                fatalError("GPIO index out of bounds")
            }
        }
    }
    
}

public struct GPIOBitField : Collection {
    
    var field0: Int
    var field1: Int
    var reserved: Int
    
    // These are computed properties, rather than constants, so that they don't take up space in the structure.
    public var startIndex: Int { return 0 }
    public var endIndex: Int { return GPIO.count }
    
    public func index(after i: Int) -> Int {
        return i + 1
    }
    
    public subscript(index: Int) -> Bool {
        get {
            let bit = 1 << (index % 32)
            switch index / 32 {
            case 0:
                return field0 & bit != 0
            case 1:
                return field1 & bit != 0
            default:
                fatalError("GPIO index out of bounds")
            }
        }
        
        set(newValue) {
            let bit = 1 << (index % 32)
            switch index / 32 {
            case 0:
                field0 |= bit
            case 1:
                field1 |= bit
            default:
                fatalError("GPIO index out of bounds")
            }
        }
    }
    
}

public enum GPIOPullUpDown : Int {
    
    case disabled = 0b00
    case pullDown = 0b01
    case pullUp   = 0b10
    
}

// FIXME: this is really an internal register map, and not a good public API.
public struct GPIO {
    
    public var functionSelect: GPIOFunctionSelect
    public var outputSet: GPIOBitField
    public var outputClear: GPIOBitField
    public var level: GPIOBitField
    public var levelDetectStatus: GPIOBitField
    public var risingEdgeDetectEnable: GPIOBitField
    public var fallingEdgeDetectEnable: GPIOBitField
    public var highDetectEnable: GPIOBitField
    public var lowDetectEnable: GPIOBitField
    public var asyncRisingEdgeDetect: GPIOBitField
    public var asyncFallingEdgeDetect: GPIOBitField
    public var pullUpDownEnable: GPIOPullUpDown
    public var pullUpDownEnableClock: GPIOBitField
    
    public static let count = 54
    
    public static let offset = 0x200000
    public static let size   = 0x0000c0
    
    public static let functionSelectOffset          = 0x00
    public static let outputSetOffset               = 0x1c
    public static let outputClearOffset             = 0x28
    public static let levelOffset                   = 0x34
    public static let levelDetectStatusOffset       = 0x40
    public static let risingEdgeDetectEnableOffset  = 0x4c
    public static let fallingEdgeDetectEnableOffset = 0x58
    public static let highDetectEnableOffset        = 0x64
    public static let lowDetectEnableOffset         = 0x70
    public static let asyncRisingEdgeDetectOffset   = 0x7c
    public static let asyncFallingEdgeDetectOffset  = 0x88
    public static let pullUpDownEnableOffset        = 0x94
    public static let pullUpDownEnableClockOffset   = 0x98
    
    // FIXME: this name is bad, and Swift-style requires the 'On' be inside the '('.
    public static func on(_ raspberryPi: RaspberryPi) throws -> UnsafeMutablePointer<GPIO> {
        // FIXME: this memory map gets leaked.
        let pointer = try raspberryPi.mapPeripheral(at: GPIO.offset, size: GPIO.size)
        return pointer.bindMemory(to: GPIO.self, capacity: 1)
    }
    
}
