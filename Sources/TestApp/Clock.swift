//
//  Clock.swift
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


let clockRegisters = try! raspberryPi.mapPeripheral(at: Clocks.offset, size: raspberryPi.pageSize)

let clockPwmControl = clockRegisters.advanced(by: Clocks.pwmOffset + Clock.controlOffset).bindMemory(to: Int.self, capacity: 1)
let clockPwmDiv = clockRegisters.advanced(by: Clocks.pwmOffset + Clock.divisorOffset).bindMemory(to: Int.self, capacity: 1)



let clockCtlPasswordShift = 24
let clockCtlMashShift = 9
let clockCtlFlip = 1 << 8
let clockCtlBusy = 1 << 7
let clockCtlKill = 1 << 5
let clockCtlEnable = 1 << 4
let clockCtlSourceShift = 0

let clockSrcGnd = 0
let clockSrcOsc = 1
let clockSrcPlld = 6

let clockCtlSrcGnd = clockSrcGnd << clockCtlSourceShift
let clockCtlSrcOsc = clockSrcOsc << clockCtlSourceShift
let clockCtlSrcPlld = clockSrcPlld << clockCtlSourceShift

let clockPassword = 0x5a << clockCtlPasswordShift

let clockDivIShift = 12
let clockDivFShift = 0

func clockDisable() {
    // Configure the PWM clock:
    // Disable clock while we modify it. Stop first, then kill.
    clockPwmControl.pointee = clockPassword | 0
    usleep(10)
    clockPwmControl.pointee = clockPassword | clockCtlKill
    while clockPwmControl.pointee & clockCtlBusy != 0 { }
}

func clockConfigure(clock: Int, divi: Int, divf: Int) {
    // Set the time and source
    clockPwmDiv.pointee = clockPassword | (divi << clockDivIShift) | (divf << clockDivFShift)
    clockPwmControl.pointee = clockPassword | (clock << clockCtlSourceShift)
    usleep(10)
    
    // Enable, with the source still set to OSC.
    clockPwmControl.pointee = clockPassword | (clock << clockCtlSourceShift) | clockCtlEnable
    usleep(10)
    while clockPwmControl.pointee & clockCtlBusy == 0 { }
}
