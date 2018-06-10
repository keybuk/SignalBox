//
//  GPIOBitField.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/10/18.
//

import Util

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
public struct GPIOBitField : Equatable, Hashable {
    
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
            let mask = UInt32.mask(except: 1, offset: shift)
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
