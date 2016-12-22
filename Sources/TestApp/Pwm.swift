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

import RaspberryPi


let pwmRegisters = try! raspberryPi.mapPeripheral(at: PWM.offset, size: PWM.size)

let pwmControl = pwmRegisters.advanced(by: PWM.controlOffset).bindMemory(to: Int.self, capacity: 1)
let pwmStatus = pwmRegisters.advanced(by: PWM.statusOffset).bindMemory(to: Int.self, capacity: 1)
let pwmDmaC = pwmRegisters.advanced(by: PWM.dmaConfigurationOffset).bindMemory(to: Int.self, capacity: 1)
let pwmRange1 = pwmRegisters.advanced(by: PWM.channel1RangeOffset).bindMemory(to: Int.self, capacity: 1)
let pwmData1 = pwmRegisters.advanced(by: PWM.channel1DataOffset).bindMemory(to: Int.self, capacity: 1)
let pwmFifo = pwmRegisters.advanced(by: PWM.fifoInputOffset).bindMemory(to: Int.self, capacity: 1)
let pwmRange2 = pwmRegisters.advanced(by: PWM.channel2RangeOffset).bindMemory(to: Int.self, capacity: 1)
let pwmData2 = pwmRegisters.advanced(by: PWM.channel2DataOffset).bindMemory(to: Int.self, capacity: 1)


let pwmRange1BusAddress = raspberryPi.peripheralBusBaseAddress + PWM.offset + PWM.channel1RangeOffset
let pwmFifoBusAddress = raspberryPi.peripheralBusBaseAddress + PWM.offset + PWM.fifoInputOffset
let pwmRange2BusAddress = raspberryPi.peripheralBusBaseAddress + PWM.offset + PWM.channel2RangeOffset


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
