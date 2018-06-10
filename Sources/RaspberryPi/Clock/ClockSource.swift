//
//  ClockSource.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/10/18.
//

/// Clock sources.
public enum ClockSource : UInt32 {
    
    case none       = 0
    case oscillator = 1
    case testDebug0 = 2
    case testDebug1 = 3
    case plla       = 4
    case pllc       = 5
    case plld       = 6
    case hdmiAux    = 7
    
}
