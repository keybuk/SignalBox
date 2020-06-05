//
//  main.swift
//  TestDMA
//
//  Created by Scott James Remnant on 5/27/20.
//

import Foundation
import RaspberryPi

// Shutdown PWM1, clear FIFO.
let pwm = try! PWM()
pwm[1].isEnabled = false
pwm[1].useFifo = false
pwm.clearFifo()

// Set PWM1 to use DMA + FIFO in 16-bit Serializer mode.
pwm.isDMAEnabled = true
pwm[1].useFifo = true
pwm[1].mode = .serializer
pwm[1].range = 16

// Stop the PWM clock.
let clock = try! Clock()
clock[.pwm].isEnabled = false
while clock[.pwm].isRunning {}

// Set the PWM clock to 0.1ms ticks.
clock[.pwm].source = .oscillator
clock[.pwm].mash = 0
clock[.pwm].divisor = ClockDivisor(integer: 1_920, fractional: 0)

// Set GPIO18 to output from PWM1.
let gpio = try! GPIO()
gpio[18].value = false
gpio[18].function = .alternateFunction5

// Grab DMA 5.
let dma = try! DMA()
dma[5].isActive = false
dma[5].reset()

// Allocate a data area for control blocks and data.
let memory = try! UncachedMemory(minimumSize: MemoryLayout<DMAControlBlock>.stride + MemoryLayout<UInt32>.stride * 256)
let controlBlock = memory.pointer.bindMemory(to: DMAControlBlock.self, capacity: 1)
let words = memory.pointer.advanced(by: MemoryLayout<DMAControlBlock>.stride).bindMemory(to: UInt32.self, capacity: 256)

// Fill the memory with the binary of 0...255, shift left because PWM uses the MSB of the data.
// (We output 8-bits of number, and an 8-bit gap of 0 because the serializer range is 16-bits).
for i in 0...255 {
    words[i] = UInt32(i) << 24
}

controlBlock[0].peripheral = .pwm
controlBlock[0].waitForWriteResponse = true
controlBlock[0].sourceAddress = memory.busAddress + UInt32(MemoryLayout<DMAControlBlock>.stride)
controlBlock[0].incrementSourceAddress = true
controlBlock[0].destinationAddress = PWM.busAddress + 0x18 /* MemoryLayout.offset(of: \PWM.Registers.fifoInput) */
controlBlock[0].destinationWaitsForDataRequest = true
controlBlock[0].transferLength = UInt32(MemoryLayout<UInt32>.stride) * 256
controlBlock[0].nextControlBlockAddress = memory.busAddress


// Start the Clock.
clock[.pwm].isEnabled = true
while !clock[.pwm].isRunning {}

// Enable the PWM.
pwm[1].isEnabled = true

// Enable the DMA.
dma[5].controlBlockAddress = memory.busAddress
dma[5].isActive = true

debugPrint(gpio[18])
debugPrint(pwm[1])
debugPrint(clock[.pwm])
debugPrint(dma[5])

print("Running, press ENTER to stop")
let _ = readLine()

// Shutdown.
gpio[18].value = false
gpio[18].function = .input

pwm[1].isEnabled = false
dma[5].isActive = false

clock[.pwm].isEnabled = false
while clock[.pwm].isRunning {}

try! memory.deallocate()
print("Bye!")
