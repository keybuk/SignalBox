//
//  DMAPeripheral.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/9/18.
//

/// DMA-capable peripherals.
///
/// - Note: BCM2835 ARM Peripherals 4.2.1.3
public enum DMAPeripheral : Int {
    
    case none        = 0
    case dsi         = 1
    case pcmTx       = 2
    case pcmRx       = 3
    case smi         = 4
    case pwm         = 5
    case spiTx       = 6
    case spiRx       = 7
    case bscTx       = 8
    case bscRx       = 9
    case eMMC        = 11
    case uartTx      = 12
    case sdHost      = 13
    case uartRx      = 14
    case dsi_1       = 15
    case slimbusMCTX = 16
    case hdmi        = 17
    case slimbusMCRC = 18
    case slimbusDC0  = 19
    case slimbusDC1  = 20
    case slimbusDC2  = 21
    case slimbusDC3  = 22
    case slimbusDC4  = 23
    case scalerFIFO0 = 24
    case scalerFIFO1 = 25
    case scalerFIFO2 = 26
    case slimbusDC5  = 27
    case slimbusDC6  = 28
    case slimbusDC7  = 29
    case slimbusDC8  = 30
    case slimbusDC9  = 31
    
}
