//
//  DMABitField.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/9/18.
//

import Util

/// DMA bit fields.
///
/// Represents a register where each bit represents one DMA channel.
///
/// The preferred way to manipulate DMA registers is through the `DMA` class, however it can
/// often be useful to interact with the registers directly.
///
///     // Set the set of enabled and disabled DMA in one shot.
///     var enabled = DMABitField()
///     enabled[1] = true
///     enabled[4] = true
///     dma.enableRegister.pointee = enabled
///
public struct DMABitField : Equatable, Hashable {
    
    internal var field: UInt32
    
    public subscript(index: Int) -> Bool {
        get {
            return field & UInt32.mask(bits: 1, offset: index) != 0
        }
        
        set {
            if newValue {
                field |= UInt32.mask(bits: 1, offset: index)
            } else {
                field &= UInt32.mask(except: 1, offset: index)
            }
        }
    }
    
    public init() {
        field = 0
    }
    
}
