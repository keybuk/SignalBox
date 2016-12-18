#if os(Linux)
    import Glibc
#else
    import Darwin
#endif


let triggerPin = 17
let pwmPin = 18


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
let gpioFlags = dmaTiNoWideBursts | dmaTiWaitResp

var cbOffset = 0

func insertZero(number: Int = 1) {
    addControlBlock(for: dataBusAddress, to: data, at: &cbOffset, flags: pwmFlags, source: zeroBusAddress, dest: pwmFifoBusAddress, length: MemoryLayout<Int>.stride * number, stride: 0)
}

func insertOnes(number: Int = 1) {
    addControlBlock(for: dataBusAddress, to: data, at: &cbOffset, flags: pwmFlags, source: oneBusAddress, dest: pwmFifoBusAddress, length: MemoryLayout<Int>.stride * number, stride: 0)
}

func insertGpioChange(pins: Int, value: Bool) {
    addControlBlock(for: dataBusAddress, to: data, at: &cbOffset, flags: gpioFlags, source: gpioBusAddress + MemoryLayout<Int>.stride * pins * 2, dest: value ? gpioPinOutputSetBusAddress : gpioPinOutputClearBusAddress, length: MemoryLayout<Int>.stride * 2, stride: 0)
}


insertZero(number: 8)

insertGpioChange(pins: 1, value: true)
insertOnes(number: 1)
insertGpioChange(pins: 1, value: false)
insertOnes(number: 1)

insertGpioChange(pins: 1, value: true)
insertOnes(number: 2)
insertGpioChange(pins: 1, value: false)
insertOnes(number: 2)

insertGpioChange(pins: 1, value: true)
insertOnes(number: 1)
insertGpioChange(pins: 1, value: false)
insertOnes(number: 1)

insertGpioChange(pins: 1, value: true)
insertOnes(number: 1)
insertGpioChange(pins: 1, value: false)
insertOnes(number: 1)

insertZero(number: 1)


// Set the trigger pin for output and clear.
setGpioFunction(gpio: triggerPin, function: gpioOut)
setGpioValue(gpio: triggerPin, value: 0)

// Set the GPIO pin for PWM output
setGpioFunction(gpio: pwmPin, function: gpioAlternate5)

pwmDisable()
pwmReset()

dmaDisable()
dmaEnableChannel()

// Set the source to OSC (19.2 MHz) and divisor to 1920, giving us a 10KHz clock.
clockDisable()
clockConfigure(clock: clockSrcOsc, divi: 1920, divf: 0)

// Use 32-bits at a time.
pwmRange1.pointee = 10

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


sleep(2)

pwmDisable()
dmaDisable()
clockDisable()

cleanup(handle: dataHandle)
