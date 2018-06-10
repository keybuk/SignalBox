//
//  GPIOPullUpDown.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/10/18.
//

/// GPIO pull-up/down enable
///
/// Defines the possible actuations of the internal pull-up/down control line for each GPIO.
public enum GPIOPullUpDown : UInt32 {
    
    case disabled = 0b00
    case pullDown = 0b01
    case pullUp   = 0b10
    
}
