#if os(Linux)
import Glibc
#else
import Darwin
#endif

import RaspberryPi


let raspberryPi = try! RaspberryPi()


let railcomGpio = 17
let dccGpio = 18
let debugGpio = 19




// Allocate control block and instructions
let (dataBusAddress, dataPointer) = try! raspberryPi.allocateUncachedMemory(pages: 1)
let data = dataPointer.bindMemory(to: Int.self, capacity: raspberryPi.pageSize / MemoryLayout<Int>.stride)

let pwmFlags = dmaTiNoWideBursts | dmaTiPwm | dmaTiSrcInc | dmaTiDestDreq | dmaTiWaitResp
let gpioFlags = dmaTiNoWideBursts | dmaTiWaitResp | dmaTiPwm | dmaTiDestDreq
let rangeFlags = dmaTiNoWideBursts | dmaTiWaitResp | dmaTiPwm | dmaTiDestDreq

var cbOffset = 0
var dataOffset = 512
var adjustOffset = 768

func addData(values: [Int]) {
    for (index, value) in values.enumerated() {
        data[dataOffset + index] = value
    }
    
    addControlBlock(for: dataBusAddress, to: data, at: &cbOffset, flags: pwmFlags, source: dataBusAddress + MemoryLayout<Int>.stride * dataOffset, dest: pwmFifoBusAddress, length: MemoryLayout<Int>.stride * values.count, stride: 0)
    
    dataOffset += values.count
}

func addRangeChange(range: Int) {
    data[adjustOffset] = range
    
    addControlBlock(for: dataBusAddress, to: data, at: &cbOffset, flags: rangeFlags, source: dataBusAddress + MemoryLayout<Int>.stride * adjustOffset, dest: pwmRange1BusAddress, length: MemoryLayout<Int>.size, stride: 0)
    
    adjustOffset += 1
}

func addGpio(pin: Int, value: Bool) {
    data[adjustOffset] = 1 << pin
    addControlBlock(for: dataBusAddress, to: data, at: &cbOffset, flags: gpioFlags, source: dataBusAddress + MemoryLayout<Int>.stride * adjustOffset, dest: value ? gpioPinOutputSetBusAddress : gpioPinOutputClearBusAddress, length: MemoryLayout<Int>.size, stride: 0)
    adjustOffset += 1
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

// Loop it
data[(cbOffset - 8) + dmaCbNextControlBlockAddressIndex] = dataBusAddress + MemoryLayout<Int>.stride * 8



// Set the railcom gpio for output and raise high.
setGpioFunction(gpio: railcomGpio, function: gpioOut)
setGpioValue(gpio: railcomGpio, value: true)

// Set the debug gpio for output and clear
setGpioFunction(gpio: debugGpio, function: gpioOut)
setGpioValue(gpio: debugGpio, value: false)

// Set the dcc gpio for PWM output
setGpioFunction(gpio: dccGpio, function: gpioAlternate5)

pwmDisable()
pwmReset()

dmaDisable()
dmaEnableChannel()

// Set the source to OSC (19.2 MHz) and divisor to 278, giving us a clock with 14.48µs bits.
clockDisable()
clockConfigure(clock: clockSrcOsc, divi: 278, divf: 0)

// Use 32-bits at a time.
pwmRange1.pointee = 32

// Enable DMA on the PWM.
pwmDmaC.pointee = pwmDmacEnable | (1 << pwmDmacPanicShift) | (1 << pwmDmacDreqShift)

// Enable PWM1 in serializer mode, using the FIFO as a source.
pwmControl.pointee = pwmCtlUseFifo1 | pwmCtlSerializerMode1 | pwmCtlPwmEnable1

// Start DMA.
dmaControlBlockAddress.pointee = dataBusAddress
usleep(100)
dmaControlStatus.pointee = dmaCsWaitForOutstandingWrites | (8 << dmaCsPanicPriorityShift) | (8 << dmaCsPriorityShift) | dmaCsActive


// Dump debug information until it stops
func debug(_ message: String) {
    print(message)
    print("PWM Status 0b" + String(pwmStatus.pointee, radix: 2))
    print("DMA Status 0b" + String(dmaControlStatus.pointee, radix: 2))
    print("DMA Debug  0b" + String(dmaDebug.pointee, radix: 2))
    print()
}

debug("DMA is on")
while dmaControlStatus.pointee & dmaCsEnd == 0 { }
debug("DMA complete")


sleep(30)

pwmDisable()
dmaDisable()
clockDisable()

//cleanup(handle: dataHandle)
