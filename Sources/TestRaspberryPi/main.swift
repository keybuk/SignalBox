//
//  main.swift
//  TestRaspberryPi
//
//  Created by Scott James Remnant on 5/27/20.
//
//

import Foundation
import RaspberryPi

do {
    let fun = try UncachedMemory(minimumSize: 512)
    print("Allocated some memory at \(String(fun.busAddress, radix:16))")

    let ints = fun.pointer.bindMemory(to: UInt32.self, capacity: 1)
    ints.pointee = 0xc0ffee

    print("\(ints.pointee.hexString)")

    try fun.deallocate()
} catch {
    fatalError("Mailbox error \(error)")
}

do {
    let gpio = try GPIO()
    for pin in gpio {
        debugPrint(pin)
    }
} catch {
    fatalError("GPIO error \(error)")
}

do {
    let clock = try Clock()
    for generator in clock {
        debugPrint(generator)
    }
} catch {
    fatalError("Clock error \(error)")
}

do {
    let pwm = try PWM()
    debugPrint(pwm)

    for channel in pwm {
        debugPrint(channel)
    }
} catch {
    fatalError("PWM error \(error)")
}

do {
    let dma = try DMA()
    for channel in dma {
        debugPrint(channel)
    }
} catch {
    fatalError("DMA error \(error)")
}
