//
//  GPIOFunction.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/10/18.
//

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
