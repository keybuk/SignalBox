//
//  GPIOFunctionSelect.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/10/18.
//

import Util

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
public struct GPIOFunctionSelect : Equatable, Hashable {
    
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
            let bits = (field >> shift) & UInt32.mask(bits: 3)
            return GPIOFunction(rawValue: bits)!
        }
        
        set {
            let shift = (index % 10) * 3
            let mask = UInt32.mask(except: 3, offset: shift)
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
