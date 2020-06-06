//
//  main.swift
//  TestFIFO
//
//  Created by Scott James Remnant on 5/27/20.
//

import Foundation
import RaspberryPi

// Shutdown PWM1, clear FIFO.
let pwm = try! PWM()
pwm[1].isEnabled = false
pwm[1].useFifo = false
pwm[2].useFifo = false
pwm.clearFifo()

// Set PWM1 to use DMA + FIFO in Serializer mode.
pwm.isDMAEnabled = true
pwm.dataRequestThreshold = 1
pwm.panicThreshold = 1
pwm[1].useFifo = true
pwm[1].mode = .serializer
pwm[1].range = 32

// Stop the PWM clock.
let clock = try! Clock()
clock[.pwm].isEnabled = false
while clock[.pwm].isRunning {}

// Set the PWM clock to 0.1ms ber byte.
clock[.pwm].source = .oscillator
clock[.pwm].mash = 0
clock[.pwm].divisor = ClockDivisor(integer: 1_920 / 8, fractional: 0)

// Set GPIO18 to output from PWM1.
let gpio = try! GPIO()
gpio[18].value = false
gpio[18].function = .alternateFunction5

gpio[17].value = false
gpio[17].function = .output

// Grab DMA 5.
let dma = try! DMA()
dma[5].isEnabled = true
dma[5].isActive = false
dma[5].abort()
dma[5].reset()

// Allocate a data area for control blocks and data.
let memory = try! UncachedMemory(minimumSize: MemoryLayout<DMAControlBlock>.stride * 16 + MemoryLayout<UInt32>.stride * 256)
let controlBlock = memory.pointer
    .bindMemory(to: DMAControlBlock.self, capacity: 16)
let words = memory.pointer
    .advanced(by: MemoryLayout<DMAControlBlock>.stride * 16)
    .bindMemory(to: UInt32.self, capacity: 256)

let wordsAddress = memory.busAddress + UInt32(MemoryLayout<DMAControlBlock>.stride * 16)

if CommandLine.arguments.count == 3,
    CommandLine.arguments[1] == "fifo",
    let numberOfWords = Int(CommandLine.arguments[2])
{
    for i in 0..<numberOfWords {
        words[i] = 0b10101010_10101010_10101010_10101010
    }

    var i = 0
    var j = 0

    controlBlock[j].peripheral = .pwm
    controlBlock[j].waitForWriteResponse = true
    controlBlock[j].sourceAddress = wordsAddress + UInt32(MemoryLayout<UInt32>.stride * i)
    controlBlock[j].destinationAddress = PWM.busAddress + 0x18 /* MemoryLayout.offset(of: \PWM.Registers.fifoInput) */
    controlBlock[j].destinationWaitsForDataRequest = true
    controlBlock[j].transferLength = UInt32(MemoryLayout<UInt32>.stride * numberOfWords)
    controlBlock[j].incrementSourceAddress = true
    controlBlock[j].nextControlBlockAddress = memory.busAddress + UInt32(MemoryLayout<DMAControlBlock>.stride * (j + 1))

    i += numberOfWords
    j += 1

    words[i] = 0b11111111_00000000_11110000_00001111

    controlBlock[j].peripheral = .pwm
    controlBlock[j].waitForWriteResponse = true
    controlBlock[j].sourceAddress = wordsAddress + UInt32(MemoryLayout<UInt32>.stride * i)
    controlBlock[j].destinationAddress = PWM.busAddress + 0x18 /* MemoryLayout.offset(of: \PWM.Registers.fifoInput) */
    controlBlock[j].destinationWaitsForDataRequest = true
    controlBlock[j].transferLength = UInt32(MemoryLayout<UInt32>.stride)
    controlBlock[j].nextControlBlockAddress = memory.busAddress + UInt32(MemoryLayout<DMAControlBlock>.stride * (j + 1))

    i += 1
    j += 1

    var setGPIO = GPIOBitField()
    var clearGPIO = GPIOBitField()
    setGPIO[17] = true

    words[i + 0] = setGPIO.field0
    words[i + 1] = setGPIO.field1
    words[i + 2] = clearGPIO.field0
    words[i + 3] = clearGPIO.field1

    controlBlock[j].peripheral = .pwm
    controlBlock[j].waitForWriteResponse = true
    controlBlock[j].sourceAddress = wordsAddress + UInt32(MemoryLayout<UInt32>.stride * i)
    controlBlock[j].destinationAddress = GPIO.busAddress + 0x1c /* MemoryLayout.offset(of: \GPIO.Registers.outputSet) */
    controlBlock[j].destinationWaitsForDataRequest = true
    controlBlock[j].is2D = true
    controlBlock[j].xLength = MemoryLayout<UInt32>.stride * 2
    controlBlock[j].yLength = 2
    controlBlock[j].sourceStride = 0
    controlBlock[j].destinationStride = MemoryLayout<UInt32>.stride
    controlBlock[j].incrementSourceAddress = true
    controlBlock[j].incrementDestinationAddress = true
    controlBlock[j].nextControlBlockAddress = memory.busAddress + UInt32(MemoryLayout<DMAControlBlock>.stride * (j + 1))

    i += 4
    j += 1

    words[i] = 0

    controlBlock[j].peripheral = .pwm
    controlBlock[j].waitForWriteResponse = true
    controlBlock[j].sourceAddress = wordsAddress + UInt32(MemoryLayout<UInt32>.stride * i)
    controlBlock[j].destinationAddress = PWM.busAddress + 0x18 /* MemoryLayout.offset(of: \PWM.Registers.fifoInput) */
    controlBlock[j].destinationWaitsForDataRequest = true
    controlBlock[j].transferLength = UInt32(MemoryLayout<UInt32>.stride)
    controlBlock[j].nextControlBlockAddress = memory.busAddress + UInt32(MemoryLayout<DMAControlBlock>.stride * (j + 1))

    i += 1
    j += 1

    setGPIO[17] = false
    clearGPIO[17] = true

    words[i + 0] = setGPIO.field0
    words[i + 1] = setGPIO.field1
    words[i + 2] = clearGPIO.field0
    words[i + 3] = clearGPIO.field1

    controlBlock[j].peripheral = .pwm
    controlBlock[j].waitForWriteResponse = true
    controlBlock[j].sourceAddress = wordsAddress + UInt32(MemoryLayout<UInt32>.stride * i)
    controlBlock[j].destinationAddress = GPIO.busAddress + 0x1c /* MemoryLayout.offset(of: \GPIO.Registers.outputSet) */
    controlBlock[j].destinationWaitsForDataRequest = true
    controlBlock[j].is2D = true
    controlBlock[j].xLength = MemoryLayout<UInt32>.stride * 2
    controlBlock[j].yLength = 2
    controlBlock[j].sourceStride = 0
    controlBlock[j].destinationStride = MemoryLayout<UInt32>.stride
    controlBlock[j].incrementSourceAddress = true
    controlBlock[j].incrementDestinationAddress = true
    controlBlock[j].nextControlBlockAddress = DMAControlBlock.stopAddress

} else if CommandLine.arguments.count == 3,
    CommandLine.arguments[1] == "range",
    let range = Int(CommandLine.arguments[2])
{
    var i = 0
    var j = 0

    words[i] = 0b11111111_00000000_11110000_00001111

    controlBlock[j].peripheral = .pwm
    controlBlock[j].waitForWriteResponse = true
    controlBlock[j].sourceAddress = wordsAddress + UInt32(MemoryLayout<UInt32>.stride * i)
    controlBlock[j].destinationAddress = PWM.busAddress + 0x18 /* MemoryLayout.offset(of: \PWM.Registers.fifoInput) */
    controlBlock[j].destinationWaitsForDataRequest = true
    controlBlock[j].transferLength = UInt32(MemoryLayout<UInt32>.stride )
    controlBlock[j].nextControlBlockAddress = memory.busAddress + UInt32(MemoryLayout<DMAControlBlock>.stride * (j + 1))

    i += 1
    j += 1

    words[i] = 0b10101010_10101010_10101010_10101010

    controlBlock[j].peripheral = .pwm
    controlBlock[j].waitForWriteResponse = true
    controlBlock[j].sourceAddress = wordsAddress + UInt32(MemoryLayout<UInt32>.stride * i)
    controlBlock[j].destinationAddress = PWM.busAddress + 0x18 /* MemoryLayout.offset(of: \PWM.Registers.fifoInput) */
    controlBlock[j].destinationWaitsForDataRequest = true
    controlBlock[j].transferLength = UInt32(MemoryLayout<UInt32>.stride)
    controlBlock[j].nextControlBlockAddress = memory.busAddress + UInt32(MemoryLayout<DMAControlBlock>.stride * (j + 1))

    i += 1
    j += 1

    words[i] = UInt32(range)

    controlBlock[j].peripheral = .pwm
    controlBlock[j].waitForWriteResponse = true
    controlBlock[j].sourceAddress = wordsAddress + UInt32(MemoryLayout<UInt32>.stride * i)
    controlBlock[j].destinationAddress = PWM.busAddress + 0x10 /* MemoryLayout.offset(of: \PWM.Registers.channel1Range) */
    controlBlock[j].destinationWaitsForDataRequest = true
    controlBlock[j].transferLength = UInt32(MemoryLayout<UInt32>.stride)
    controlBlock[j].nextControlBlockAddress = memory.busAddress + UInt32(MemoryLayout<DMAControlBlock>.stride * (j + 1))

    i += 1
    j += 1

    words[i] = 0b11111111_00000000_11110000_00001111

    controlBlock[j].peripheral = .pwm
    controlBlock[j].waitForWriteResponse = true
    controlBlock[j].sourceAddress = wordsAddress + UInt32(MemoryLayout<UInt32>.stride * i)
    controlBlock[j].destinationAddress = PWM.busAddress + 0x18 /* MemoryLayout.offset(of: \PWM.Registers.fifoInput) */
    controlBlock[j].destinationWaitsForDataRequest = true
    controlBlock[j].transferLength = UInt32(MemoryLayout<UInt32>.stride )
    controlBlock[j].nextControlBlockAddress = memory.busAddress + UInt32(MemoryLayout<DMAControlBlock>.stride * (j + 1))

    i += 1
    j += 1

    words[i] = 32

    controlBlock[j].peripheral = .pwm
    controlBlock[j].waitForWriteResponse = true
    controlBlock[j].sourceAddress = wordsAddress + UInt32(MemoryLayout<UInt32>.stride * i)
    controlBlock[j].destinationAddress = PWM.busAddress + 0x10 /* MemoryLayout.offset(of: \PWM.Registers.channel1Range) */
    controlBlock[j].destinationWaitsForDataRequest = true
    controlBlock[j].transferLength = UInt32(MemoryLayout<UInt32>.stride)
    controlBlock[j].nextControlBlockAddress = DMAControlBlock.stopAddress

} else {
    words[0] = ~1

    controlBlock[0].peripheral = .pwm
    controlBlock[0].waitForWriteResponse = true
    controlBlock[0].sourceAddress = wordsAddress
    controlBlock[0].incrementSourceAddress = false
    controlBlock[0].destinationAddress = PWM.busAddress + 0x18 /* MemoryLayout.offset(of: \PWM.Registers.fifoInput) */
    controlBlock[0].destinationWaitsForDataRequest = true
    controlBlock[0].transferLength = UInt32(MemoryLayout<UInt32>.stride)
    controlBlock[0].nextControlBlockAddress = DMAControlBlock.stopAddress
}

// Start the Clock.
clock[.pwm].isEnabled = true
while !clock[.pwm].isRunning {}

// Enable the PWM.
pwm[1].isEnabled = true

// Enable the DMA.
dma[5].controlBlockAddress = memory.busAddress
dma[5].isActive = true

debugPrint(gpio[18])
debugPrint(pwm)
debugPrint(pwm[1])
debugPrint(clock[.pwm])
debugPrint(dma[5])

print("Running, press ENTER to stop")
let _ = readLine()

// Shutdown.
gpio[18].value = false
gpio[18].function = .input

gpio[17].value = false
gpio[17].function = .input

pwm[1].isEnabled = false
dma[5].isActive = false

clock[.pwm].isEnabled = false
while clock[.pwm].isRunning {}

try! memory.deallocate()
print("Bye!")
