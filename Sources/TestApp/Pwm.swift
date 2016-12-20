//
//  Pwm.swift
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

let pwmRegistersOffset = 0x20c000
let pwmControlOffset = 0x00
let pwmStatusOffset = 0x04
let pwmDmaCOffset = 0x08
let pwmRange1Offset = 0x010
let pwmData1Offset = 0x14
let pwmFifoOffset = 0x18
let pwmRange2Offset = 0x020
let pwmData2Offset = 0x24

let pwmRegisters = mapPeripheral(at: pwmRegistersOffset)

let pwmControl = pwmRegisters.advanced(by: pwmControlOffset).bindMemory(to: Int.self, capacity: 1)
let pwmStatus = pwmRegisters.advanced(by: pwmStatusOffset).bindMemory(to: Int.self, capacity: 1)
let pwmDmaC = pwmRegisters.advanced(by: pwmDmaCOffset).bindMemory(to: Int.self, capacity: 1)
let pwmRange1 = pwmRegisters.advanced(by: pwmRange1Offset).bindMemory(to: Int.self, capacity: 1)
let pwmData1 = pwmRegisters.advanced(by: pwmData1Offset).bindMemory(to: Int.self, capacity: 1)
let pwmFifo = pwmRegisters.advanced(by: pwmFifoOffset).bindMemory(to: Int.self, capacity: 1)
let pwmRange2 = pwmRegisters.advanced(by: pwmRange2Offset).bindMemory(to: Int.self, capacity: 1)
let pwmData2 = pwmRegisters.advanced(by: pwmData2Offset).bindMemory(to: Int.self, capacity: 1)


let pwmRange1BusAddress = peripheralBusBaseAddress + pwmRegistersOffset + pwmRange1Offset
let pwmFifoBusAddress = peripheralBusBaseAddress + pwmRegistersOffset + pwmFifoOffset
let pwmRange2BusAddress = peripheralBusBaseAddress + pwmRegistersOffset + pwmRange2Offset


let pwmCtlMarkspaceEnable2 = 1 << 15
let pwmCtlUseFifo2 = 1 << 13
let pwmCtlPolarity2 = 1 << 12
let pwmCtlSilenceBit2 = 1 << 11
let pwmCtlRepeatLast2 = 1 << 10
let pwmCtlSerializerMode2 = 1 << 9
let pwmCtlPwmEnable2 = 1 << 8
let pwmCtlMarkspaceEnable1 = 1 << 7
let pwmCtlClearFifo = 1 << 6
let pwmCtlUseFifo1 = 1 << 5
let pwmCtlPolarity1 = 1 << 4
let pwmCtlSilenceBit1 = 1 << 3
let pwmCtlRepeatLast1 = 1 << 2
let pwmCtlSerializerMode1 = 1 << 1
let pwmCtlPwmEnable1 = 1 << 0

let pwmDmacEnable = 1 << 31
let pwmDmacPanicShift = 8
let pwmDmacDreqShift = 0

let pwmStatusChannel4State = 1 << 12
let pwmStatusChannel3State = 1 << 11
let pwmStatusChannel2State = 1 << 10
let pwmStatusChannel1State = 1 << 9
let pwmStatusBusError = 1 << 8
let pwmStatusChannel4GapOccurred = 1 << 7
let pwmStatusChannel3GapOccurred = 1 << 6
let pwmStatusChannel2GapOccurred = 1 << 5
let pwmStatusChannel1GapOccurred = 1 << 4
let pwmStatusFifoReadError = 1 << 3
let pwmStatusFifoWriteError = 1 << 2
let pwmStatusFifoEmpty = 1 << 1
let pwmStatusFifoFull = 1 << 0


func pwmDisable() {
    pwmControl.pointee = 0
    pwmDmaC.pointee = 0
    usleep(100)
}

func pwmReset() {
    // Clear the FIFO and error bits.
    pwmControl.pointee = pwmCtlClearFifo
    pwmStatus.pointee = pwmStatusBusError | pwmStatusFifoReadError | pwmStatusFifoWriteError | pwmStatusChannel1GapOccurred | pwmStatusChannel2GapOccurred | pwmStatusChannel3GapOccurred | pwmStatusChannel4GapOccurred
    pwmData1.pointee = 0
    pwmData2.pointee = 0
    usleep(100)
}
