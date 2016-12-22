//
//  Dma.swift
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

let dmaRegistersOffset = 0x007000
let dmaEnableOffset = 0xff0

let dmaRegisters = try! raspberryPi.mapPeripheral(at: dmaRegistersOffset, size: raspberryPi.pageSize)

let dmaEnable = dmaRegisters.advanced(by: dmaEnableOffset).bindMemory(to: Int.self, capacity: 1)


let dmaChannelSize = 0x000100

let dmaControlStatusOffset = 0x00
let dmaControlBlockAddressOffset = 0x04
let dmaDebugOffset = 0x20

let dmaChannel = 5
let dmaChannelRegisters = dmaRegisters.advanced(by: dmaChannel * dmaChannelSize)

let dmaControlStatus = dmaChannelRegisters.advanced(by: dmaControlStatusOffset).bindMemory(to: Int.self, capacity: 1)
let dmaControlBlockAddress = dmaChannelRegisters.advanced(by: dmaControlBlockAddressOffset).bindMemory(to: Int.self, capacity: 1)
let dmaDebug = dmaChannelRegisters.advanced(by: dmaDebugOffset).bindMemory(to: Int.self, capacity: 1)


let dmaCbTransferInformationIndex = 0
let dmaCbSourceAddressIndex = 1
let dmaCbDestinationAddressIndex = 2
let dmaCbTransferLengthIndex = 3
let dmaCb2dModeStrideIndex = 4
let dmaCbNextControlBlockAddressIndex = 5

func addControlBlock(for busAddress: Int, to data: UnsafeMutablePointer<Int>, at offset: inout Int, flags: Int, source: Int, dest: Int, length: Int, stride: Int) {
    if offset > 0 {
        data[(offset - 8) + dmaCbNextControlBlockAddressIndex] = busAddress + MemoryLayout<Int>.stride * offset
    }
    
    data[offset + dmaCbTransferInformationIndex] = flags
    data[offset + dmaCbSourceAddressIndex] = source
    data[offset + dmaCbDestinationAddressIndex] = dest
    data[offset + dmaCbTransferLengthIndex] = length
    data[offset + dmaCb2dModeStrideIndex] = stride
    data[offset + dmaCbNextControlBlockAddressIndex] = 0
    data[offset + 6] = 0
    data[offset + 7] = 0
    offset += 8
}

let dmaCsReset = 1 << 31
let dmaCsAbort = 1 << 30
let dmaCsDisDebug = 1 << 29
let dmaCsWaitForOutstandingWrites = 1 << 28
let dmaCsPanicPriorityShift = 20
let dmaCsPriorityShift = 16
let dmaCsError = 1 << 8
let dmaCsWaitingForOutsandingWrites = 1 << 6
let dmaCsDreqStopsDma = 1 << 5
let dmaCsPaused = 1 << 4
let dmaCsDreq = 1 << 3
let dmaCsInterruptStatus = 1 << 2
let dmaCsEnd = 1 << 1
let dmaCsActive = 1 << 0

let dmaTiNoWideBursts = 1 << 26
let dmaTiWaitCyclesShift = 21
let dmaTiPermapShift = 16
let dmaTiBurstLengthShift = 12
let dmaTiSrcIgnore = 1 << 11
let dmaTiSrcDreq = 1 << 10
let dmaTiSrcWidth = 1 << 9
let dmaTiSrcInc = 1 << 8
let dmaTiDestIgnore = 1 << 7
let dmaTiDestDreq = 1 << 6
let dmaTiDestWidth = 1 << 5
let dmaTiDestInc = 1 << 4
let dmaTiWaitResp = 1 << 3
let dmaTiTdMode = 1 << 1
let dmaTiIntEn = 1 << 0

let dmaPermapPwm = 5

let dmaTiPwm = (dmaPermapPwm << dmaTiPermapShift)

let dmaDebugReadError = 1 << 2
let dmaDebugFifoError = 1 << 1
let dmaDebugReadLastNotSetError = 1 << 0


func dmaDisable() {
    dmaControlStatus.pointee = dmaCsAbort
    usleep(100)
    dmaControlStatus.pointee = dmaCsReset
    usleep(100)
    dmaDebug.pointee = dmaDebugReadError | dmaDebugFifoError | dmaDebugReadLastNotSetError
    usleep(100)
}

func dmaEnableChannel() {
    dmaEnable.pointee |= 1 << dmaChannel
    usleep(100)
}

