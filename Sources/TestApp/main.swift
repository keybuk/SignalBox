#if os(Linux)
import Glibc
#else
import Darwin
#endif

import RaspberryPi


let raspberryPi = try! RaspberryPi()
let gpio = try! GPIO.on(raspberryPi)
let clock = try! Clock.pwm(on: raspberryPi)
let pwm = try! PWM.on(raspberryPi)
let dma = try! DMA.on(raspberryPi)


let railcomGpio = 17
let dccGpio = 18
let debugGpio = 19

let dmaChannel = 5


// Allocate control block and instructions
let (dataBusAddress, dataPointer) = try! raspberryPi.allocateUncachedMemory(pages: 1)

let dataOffset = raspberryPi.pageSize / 2

let controlBlocks = dataPointer.bindMemory(to: DMAControlBlock.self, capacity: dataOffset / MemoryLayout<DMAControlBlock>.stride)
let data = dataPointer.advanced(by: dataOffset).bindMemory(to: Int.self, capacity: (raspberryPi.pageSize - dataOffset) / MemoryLayout<Int>.stride)

var cbIndex = 0
var dataIndex = 0

func addData(values: [Int]) {
    for (index, value) in values.enumerated() {
        data[dataIndex + index] = value
    }
    
    if cbIndex > 0 {
        controlBlocks[cbIndex - 1].nextControlBlockAddress = dataBusAddress + MemoryLayout<DMAControlBlock>.stride * cbIndex
    }
    
    controlBlocks[cbIndex].transferInformation = [ .noWideBursts, .peripheralMapping(.pwm), .sourceAddressIncrement, .destinationDREQ, .waitForWriteResponse ]
    controlBlocks[cbIndex].sourceAddress = dataBusAddress + dataOffset + MemoryLayout<Int>.stride * dataIndex
    controlBlocks[cbIndex].destinationAddress = raspberryPi.peripheralBusBaseAddress + PWM.offset + PWM.fifoInputOffset
    controlBlocks[cbIndex].transferLength = MemoryLayout<Int>.stride * values.count
    controlBlocks[cbIndex].tdModeStride = 0
    controlBlocks[cbIndex].nextControlBlockAddress = 0
    
    dataIndex += values.count
    cbIndex += 1
}

func addRangeChange(range: Int) {
    data[dataIndex] = range
    
    if cbIndex > 0 {
        controlBlocks[cbIndex - 1].nextControlBlockAddress = dataBusAddress + MemoryLayout<DMAControlBlock>.stride * cbIndex
    }
    
    controlBlocks[cbIndex].transferInformation = [ .noWideBursts, .peripheralMapping(.pwm), .destinationDREQ, .waitForWriteResponse ]
    controlBlocks[cbIndex].sourceAddress = dataBusAddress + dataOffset + MemoryLayout<Int>.stride * dataIndex
    controlBlocks[cbIndex].destinationAddress = raspberryPi.peripheralBusBaseAddress + PWM.offset + PWM.channel1RangeOffset
    controlBlocks[cbIndex].transferLength = MemoryLayout<Int>.stride
    controlBlocks[cbIndex].tdModeStride = 0
    controlBlocks[cbIndex].nextControlBlockAddress = 0
    
    dataIndex += 1
    cbIndex += 1
}

func addGpio(pin: Int, value: Bool) {
    data[dataIndex] = 1 << pin

    if cbIndex > 0 {
        controlBlocks[cbIndex - 1].nextControlBlockAddress = dataBusAddress + MemoryLayout<DMAControlBlock>.stride * cbIndex
    }

    controlBlocks[cbIndex].transferInformation = [ .noWideBursts, .peripheralMapping(.pwm), .destinationDREQ, .waitForWriteResponse ]
    controlBlocks[cbIndex].sourceAddress = dataBusAddress + dataOffset + MemoryLayout<Int>.stride * dataIndex
    controlBlocks[cbIndex].destinationAddress = raspberryPi.peripheralBusBaseAddress + GPIO.offset + (value ? GPIO.outputSetOffset : GPIO.outputClearOffset)
    controlBlocks[cbIndex].transferLength = MemoryLayout<Int>.stride
    controlBlocks[cbIndex].tdModeStride = 0
    controlBlocks[cbIndex].nextControlBlockAddress = 0

    dataIndex += 1
    cbIndex += 1
}


addData(values: [
    0, 0, 0, 0,
    Int(bitPattern: 0b11110000_11110000_11110000_11110000)
    ])

addData(values: [
    Int(bitPattern: 0b11110000_11110000_11110000_11110000),
    Int(bitPattern: 0b11110000_11110000_11110000_11110000),
    Int(bitPattern: 0b11110000_11110000) << 16
    ])
addRangeChange(range: 16)

addData(values: [
    Int(bitPattern: 0b11111110_00000011_11111000_00001111)
    ])
addRangeChange(range: 32)

addData(values: [
    Int(bitPattern: 0b11100000_00111111_10000000_11111110)
    ])
addGpio(pin: debugGpio, value: true)

addData(values: [
    Int(bitPattern: 0b00000011_11111000_00001111_11100000),
    Int(bitPattern: 0b00111100_00111100_00111111_10000000),
    Int(bitPattern: 0b11111110_00000011_11000011_11000011),
    Int(bitPattern: 0b11000011_11000011_11111000_00001111),
    Int(bitPattern: 0b11100000_00111111_10000000_11111110),
    Int(bitPattern: 0b00000011_11111000_00001111_00001111),
    Int(bitPattern: 0b00001111_00001111_00001111_11100000),
    Int(bitPattern: 0b00111100_00111100_00111100_0011) << 4
    ])
addRangeChange(range: 28)

addData(values: [
    Int(bitPattern: 0b11000011_11000011_11000011_11000011)
    ])
addRangeChange(range: 32)

addData(values: [
    Int(bitPattern: 0b110000) << 26,
    ])
addRangeChange(range: 6)
addGpio(pin: railcomGpio, value: false)

addData(values: [
    Int(bitPattern: 0b11110000_11110000_11110000_11110000)
    ])
addRangeChange(range: 32)
addGpio(pin: railcomGpio, value: true)
addGpio(pin: debugGpio, value: false)

// Loop it to the second control block.
controlBlocks[cbIndex - 1].nextControlBlockAddress = dataBusAddress + MemoryLayout<DMAControlBlock>.stride



// Set the railcom gpio for output and raise high.
gpio.pointee.functionSelect[railcomGpio] = .output
gpio.pointee.outputSet[railcomGpio] = true

// Set the debug gpio for output and clear
gpio.pointee.functionSelect[debugGpio] = .output
gpio.pointee.outputSet[debugGpio] = false

// Set the dcc gpio for PWM output
gpio.pointee.functionSelect[dccGpio] = .alternateFunction5

pwm.pointee.disable()
pwm.pointee.reset()

dma.enable.pointee |= 1 << dmaChannel
usleep(100)
dma.channel[dmaChannel].pointee.controlStatus.insert(.abort)
usleep(100)
dma.channel[dmaChannel].pointee.reset()

// Set the source to OSC (19.2 MHz) and divisor to 278, giving us a clock with 14.48µs bits.
clock.pointee.disable()
clock.pointee.control = [ .source(.oscillator), .mash(.integer) ]
clock.pointee.divisor = [ .integer(278) ]
clock.pointee.enable()

// Use 32-bits at a time.
pwm.pointee.channel1Range = 32

// Enable DMA on the PWM.
pwm.pointee.dmaConfiguration = [ .enabled, .dreqThreshold(1), .panicThreshold(1) ]

// Enable PWM1 in serializer mode, using the FIFO as a source.
pwm.pointee.control = [ .channel1UseFifo, .channel1SerializerMode, .channel1Enable ]

// Start DMA.
dma.channel[dmaChannel].pointee.controlBlockAddress = dataBusAddress
usleep(100)
dma.channel[dmaChannel].pointee.controlStatus = [ .waitForOutstandingWrites, .priorityLevel(8), .panicPriorityLevel(8), .active ]


// Dump debug information until it stops
func debug(_ message: String) {
    print(message)
    print("PWM Status 0b" + String(pwm.pointee.status.rawValue, radix: 2))
    print("DMA Status 0b" + String(dma.channel[dmaChannel].pointee.controlStatus.rawValue, radix: 2))
    print("DMA Debug  0b" + String(dma.channel[dmaChannel].pointee.debug.rawValue, radix: 2))
    print()
}

debug("DMA is on")
while !dma.channel[dmaChannel].pointee.controlStatus.contains(.transferComplete) { }
debug("DMA complete")


sleep(30)

pwm.pointee.disable()
dma.channel[dmaChannel].pointee.controlStatus.insert(.abort)
clock.pointee.disable()

//cleanup(handle: dataHandle)
