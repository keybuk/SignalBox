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

public enum GPIOPullUpDown : Int {
    
    case disabled = 0b00
    case pullDown = 0b01
    case pullUp   = 0b10

}

public enum GPIO {
    
    public static let offset = 0x200000
    public static let size   = 0x0000c0
    
    public static let functionSelectOffset             = 0x00
    public static let pinOutputSetOffset               = 0x1c
    public static let pinOutputClearOffset             = 0x28
    public static let pinLevelOffset                   = 0x34
    public static let pinLevelDetectStatusOffset       = 0x40
    public static let pinRisingEdgeDetectEnableOffset  = 0x4c
    public static let pinFallingEdgeDetectEnableOffset = 0x58
    public static let pinHighDetectEnableOffset        = 0x64
    public static let pinLowDetectEnableOffset         = 0x70
    public static let pinAsyncRisingEdgeDetectOffset   = 0x7c
    public static let pinAsyncFallingEdgeDetectOffset  = 0x88
    public static let pinPullUpDownEnableOffset        = 0x94
    public static let pinPullUpDownEnableClockOffset   = 0x98
    public static let testOffset                       = 0x80

}
