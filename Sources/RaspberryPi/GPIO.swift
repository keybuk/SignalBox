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
    
    public var field0: Int
    public var field1: Int
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
                if newValue {
                    field0 |= bit
                } else {
                    field0 &= ~bit
                }
            case 1:
                if newValue {
                    field1 |= bit
                } else {
                    field1 &= ~bit
                }
            default:
                fatalError("GPIO index out of bounds")
            }
        }
    }
    
    public init(field0: Int = 0, field1: Int = 0) {
        self.field0 = field0
        self.field1 = field1
        reserved = 0
    }
    
}

public enum GPIOPullUpDown : Int {
    
    case disabled = 0b00
    case pullDown = 0b01
    case pullUp   = 0b10
    
}

public struct GPIO {

    let number: Int
    
    struct Registers {
        var functionSelect: GPIOFunctionSelect
        var outputSet: GPIOBitField
        var outputClear: GPIOBitField
        var level: GPIOBitField
        // FIXME: the following registers are unimplemented.
        var levelDetectStatus: GPIOBitField
        var risingEdgeDetectEnable: GPIOBitField
        var fallingEdgeDetectEnable: GPIOBitField
        var highDetectEnable: GPIOBitField
        var lowDetectEnable: GPIOBitField
        var asyncRisingEdgeDetect: GPIOBitField
        var asyncFallingEdgeDetect: GPIOBitField
        var pullUpDownEnable: GPIOPullUpDown
        var pullUpDownEnableClock: GPIOBitField
    }

    let registers: UnsafeMutablePointer<Registers>

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

    public var function: GPIOFunction {
        get { return registers.pointee.functionSelect[number] }
        set { registers.pointee.functionSelect[number] = newValue }
    }
    
    public var value: Bool {
        get { return registers.pointee.level[number] }
        set {
            if newValue {
                registers.pointee.outputSet[number] = true
            } else {
                registers.pointee.outputClear[number] = true
            }
        }
    }

    init(number: Int, peripherals: UnsafeMutableRawPointer) {
        self.number = number
        self.registers = peripherals.advanced(by: GPIO.offset).bindMemory(to: Registers.self, capacity: 1)
    }

}
