#if os(Linux)
    import Glibc
#else
    import Darwin
#endif


let triggerPin = 17
let pwmPin = 18
let otherPin = 19


// Allocate control block and instructions
let (dataHandle, dataBusAddress, dataPhysicalAddress, data) = makeUncachedMap(pages: 1)

// 128 0s and 128 1s
let dataOffset = 512
let zeroOffset = dataOffset
let zeroBusAddress = dataBusAddress + MemoryLayout<Int>.stride * zeroOffset
for i in 0..<128 {
    data[zeroOffset + i] = Int(bitPattern: 0x00000000)
}

let oneOffset = dataOffset + 128
let oneBusAddress = dataBusAddress + MemoryLayout<Int>.stride * oneOffset
for i in 0..<128 {
    data[oneOffset + i] = Int(bitPattern: 0xffffffff)
}

// Two words here, for the two Set/Clear registers
let gpioOffset = dataOffset + 256
let gpioBusAddress = dataBusAddress + MemoryLayout<Int>.stride * gpioOffset
data[gpioOffset + 0] = 0
data[gpioOffset + 1] = 0

data[gpioOffset + 2] = (1 << triggerPin)
data[gpioOffset + 3] = 0


// Flags
// still experimenting with Dreq on Gpio
let pwmFlags = dmaTiNoWideBursts | dmaTiPwm | dmaTiSrcInc | dmaTiDestDreq | dmaTiWaitResp
let gpioFlags = dmaTiNoWideBursts | dmaTiWaitResp | dmaTiPwm | dmaTiDestDreq
let rangeFlags = dmaTiNoWideBursts | dmaTiWaitResp | dmaTiPwm | dmaTiDestDreq

var cbOffset = 0

func insertZeros(number: Int = 1) {
    addControlBlock(for: dataBusAddress, to: data, at: &cbOffset, flags: pwmFlags, source: zeroBusAddress, dest: pwmFifoBusAddress, length: MemoryLayout<Int>.stride * number, stride: 0)
}

func insertOnes(number: Int = 1) {
    addControlBlock(for: dataBusAddress, to: data, at: &cbOffset, flags: pwmFlags, source: oneBusAddress, dest: pwmFifoBusAddress, length: MemoryLayout<Int>.stride * number, stride: 0)
}

func insertGpioChange(pins: Int, value: Bool) {
    addControlBlock(for: dataBusAddress, to: data, at: &cbOffset, flags: gpioFlags, source: gpioBusAddress + MemoryLayout<Int>.stride * pins * 2, dest: value ? gpioPinOutputSetBusAddress : gpioPinOutputClearBusAddress, length: MemoryLayout<Int>.stride * 2, stride: 0)
}

insertZeros(number: 16)

insertOnes(number: 2)
insertZeros(number: 2)
insertOnes(number: 2)
insertZeros(number: 2)

// want the gpio and range here
insertOnes(number: 2)

// after just one with dreq - ie. write to fifo, wait for dreq to indicate it's going to pwm, change range for it
data[768] = 16
addControlBlock(for: dataBusAddress, to: data, at: &cbOffset, flags: rangeFlags, source: dataBusAddress + MemoryLayout<Int>.stride * 768, dest: pwmRange1BusAddress, length: MemoryLayout<Int>.size, stride: 0)
addControlBlock(for: dataBusAddress, to: data, at: &cbOffset, flags: rangeFlags, source: dataBusAddress + MemoryLayout<Int>.stride * 768, dest: pwmRange2BusAddress, length: MemoryLayout<Int>.size, stride: 0)

insertZeros(number: 2)

// after two with dreq - ie. it's gone in and out of the fifo, and then there's obviously one more "next" word in there
insertGpioChange(pins: 1, value: true)

insertOnes(number: 2)
insertZeros(number: 2)

// want the gpio and range here
insertOnes(number: 2)

data[769] = 32
addControlBlock(for: dataBusAddress, to: data, at: &cbOffset, flags: rangeFlags, source: dataBusAddress + MemoryLayout<Int>.stride * 769, dest: pwmRange1BusAddress, length: MemoryLayout<Int>.size, stride: 0)
addControlBlock(for: dataBusAddress, to: data, at: &cbOffset, flags: rangeFlags, source: dataBusAddress + MemoryLayout<Int>.stride * 769, dest: pwmRange2BusAddress, length: MemoryLayout<Int>.size, stride: 0)

insertZeros(number: 2)

insertGpioChange(pins: 1, value: false)

insertOnes(number: 2)
insertZeros(number: 2)
insertOnes(number: 2)
insertZeros(number: 2)

insertOnes(number: 8)

/*
// GPIO FIRST
 
insertGpioChange(pins: 1, value: true)
insertOnes(number: 2)
insertGpioChange(pins: 1, value: false)
insertOnes(number: 2)

insertGpioChange(pins: 1, value: true)
insertOnes(number: 4)
insertGpioChange(pins: 1, value: false)
insertOnes(number: 4)

insertGpioChange(pins: 1, value: true)
insertOnes(number: 2)
insertGpioChange(pins: 1, value: false)
insertOnes(number: 2)

insertGpioChange(pins: 1, value: true)
insertOnes(number: 2)
insertGpioChange(pins: 1, value: false)
insertOnes(number: 2)
*/

/*
// GPIO SECOND
insertOnes(number: 2)
insertGpioChange(pins: 1, value: true)
insertOnes(number: 2)
insertGpioChange(pins: 1, value: false)

insertOnes(number: 4)
insertGpioChange(pins: 1, value: true)
insertOnes(number: 4)
insertGpioChange(pins: 1, value: false)

insertOnes(number: 2)
insertGpioChange(pins: 1, value: true)
insertOnes(number: 2)
insertGpioChange(pins: 1, value: false)

insertOnes(number: 2)
insertGpioChange(pins: 1, value: true)
insertOnes(number: 2)
insertGpioChange(pins: 1, value: false)
*/

/*
// RANGE AFTER TWO
insertGpioChange(pins: 1, value: true)

insertOnes(number: 1)
insertZeros(number: 1)

insertOnes(number: 1)
insertZeros(number: 1)

let rangeFlags = dmaTiNoWideBursts | dmaTiWaitResp //| dmaTiPwm | dmaTiDestDreq
data[768] = 5
addControlBlock(for: dataBusAddress, to: data, at: &cbOffset, flags: rangeFlags, source: dataBusAddress + MemoryLayout<Int>.stride * 768, dest: pwmRange1BusAddress, length: MemoryLayout<Int>.size, stride: 0)

insertOnes(number: 1)
insertZeros(number: 1)

insertOnes(number: 1)
insertZeros(number: 1)

insertOnes(number: 1)
insertZeros(number: 1)

insertOnes(number: 1)
insertZeros(number: 1)

data[769] = 10
addControlBlock(for: dataBusAddress, to: data, at: &cbOffset, flags: rangeFlags, source: dataBusAddress + MemoryLayout<Int>.stride * 769, dest: pwmRange1BusAddress, length: MemoryLayout<Int>.size, stride: 0)

insertOnes(number: 1)
insertZeros(number: 1)

insertOnes(number: 1)
insertZeros(number: 1)

insertOnes(number: 1)
insertZeros(number: 1)

insertOnes(number: 1)
insertZeros(number: 1)
*/


// PWM often ignores "don't repeat last" so explicitly zero and also explicitly drop the trigger pin in case I left it up.
insertZeros(number: 4)
insertGpioChange(pins: 1, value: false)


// Set the trigger pin for output and clear.
setGpioFunction(gpio: triggerPin, function: gpioOut)
setGpioValue(gpio: triggerPin, value: 0)

// Set the GPIO pin for PWM output
setGpioFunction(gpio: pwmPin, function: gpioAlternate5)
setGpioFunction(gpio: otherPin, function: gpioAlternate5)

pwmDisable()
pwmReset()

dmaDisable()
dmaEnableChannel()

// Set the source to OSC (19.2 MHz) and divisor to 1920, giving us a 10KHz clock.
clockDisable()
clockConfigure(clock: clockSrcOsc, divi: 600, divf: 0)

// Use 32-bits at a time.
pwmRange1.pointee = 32
pwmRange2.pointee = 32

// Enable DMA on the PWM.
pwmDmaC.pointee = pwmDmacEnable | (2 << pwmDmacPanicShift) | (2 << pwmDmacDreqShift)

// Enable PWM1 in serializer mode, using the FIFO as a source.
pwmControl.pointee = pwmCtlUseFifo1 | pwmCtlSerializerMode1 | pwmCtlPwmEnable1 | pwmCtlUseFifo2 | pwmCtlSerializerMode2 | pwmCtlPwmEnable2

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


sleep(2)

pwmDisable()
dmaDisable()
clockDisable()

cleanup(handle: dataHandle)
