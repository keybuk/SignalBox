//
//  Gpio.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/18/16.
//
//

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif


let gpioRegistersOffset = 0x200000
let gpioFunctionSelectOffset = 0x00
let gpioPinOutputSetOffset = 0x1c
let gpioPinOutputClearOffset = 0x28

let gpioRegisters = mapPeripheral(at: gpioRegistersOffset)

let gpioFunctionSelect = gpioRegisters.advanced(by: gpioFunctionSelectOffset).bindMemory(to: Int.self, capacity: 2)
let gpioPinOutputSet = gpioRegisters.advanced(by: gpioPinOutputSetOffset).bindMemory(to: Int.self, capacity: 2)
let gpioPinOutputClear = gpioRegisters.advanced(by: gpioPinOutputClearOffset).bindMemory(to: Int.self, capacity: 2)


let gpioIn = 0b000
let gpioOut = 0b001
let gpioAlternate0 = 0b101
let gpioAlternate1 = 0b101
let gpioAlternate2 = 0b110
let gpioAlternate3 = 0b111
let gpioAlternate4 = 0b011
let gpioAlternate5 = 0b010

func setGpioFunction(gpio: Int, function: Int) {
    gpioFunctionSelect[gpio / 10] &= ~(0b111 << ((gpio % 10) * 3))
    gpioFunctionSelect[gpio / 10] |= function << ((gpio % 10) * 3)
}

func setGpioValue(gpio: Int, value: Bool) {
    let index = gpio / 32
    let bit = 1 << (gpio % 32)

    if value {
        gpioPinOutputSet[index] = bit
    } else {
        gpioPinOutputClear[index] = bit
    }
}


let gpioPinOutputSetBusAddress = peripheralBusBaseAddress + gpioRegistersOffset + gpioPinOutputSetOffset
let gpioPinOutputClearBusAddress = peripheralBusBaseAddress + gpioRegistersOffset + gpioPinOutputClearOffset
