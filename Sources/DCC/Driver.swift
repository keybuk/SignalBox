//
//  Driver.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/20/16.
//
//

#if os(Linux)
import Glibc
#else
import Darwin
#endif

import Foundation // for substring
import Dispatch

import RaspberryPi


/// Driver utilizes the Raspberry Pi hardware to output a DCC bitstream.
///
/// The PWM is used to generate the basic bitstream, with the FIFO sourced from memory by the DMA engine. Combining the two in this way reduces the memory bandwidth by a factor of 32, since the PWM can receive 32 physical bits with each DMA transfer.
///
/// Since there are not sufficient PWM channels, GPIOs are used directly from the DMA engine for the RailCom cutout, and the debug signal. Testing revealed that the control blocks to adjust the GPIOs must be synchronized with the second DREQ after the one for the word they are to be synchronized with, to allow that word to pass through the FIFO and into the PWM hardware. Much of the logic of this class is handling that delaying compared to the bitstream, including across the loop at the end of the data.
///
/// In addition, since the DREQ is synchronized to PWM word boundaries, it is necessary to regularly use the DMA engine to adjust the Range register of the PWM so a GPIO can be raised or lowered at the correct physical bit boundary, which may not otherwise fall on a word boundary. Testing revealed that the control block for this Range register change must be synchronized with the first DREQ after the one for the word it is to adjust. The need to shortern a word is already conveyed in the bitstream through the `size` payload.
public class Driver {
    
    public enum DriverError: Error {
        case infiniteLoop
    }
    
    let railcomGpio = 17
    let dccGpio = 18
    let debugGpio = 19

    let dmaChannelNumber = 5
    
    // Set the source to OSC (19.2 MHz) and divisor to 278, giving us a clock with 14.48µs bits.
    let clockSource: ClockControl = [ .source(.oscillator), .mash(.integer) ]
    let clockDivisor: ClockDivisor = [ .integer(278) ]
    
    // FIXME not sure which way round I want to do this, start with the bit duration and calculate the clock?
    public let bitDuration: Float = 1000000 / (19200000.0 / Float(278))

    let eventDelay = 2
    
    let raspberryPi: RaspberryPi
    let gpio: UnsafeMutablePointer<GPIO>
    let clock: UnsafeMutablePointer<Clock>
    let pwm: UnsafeMutablePointer<PWM>
    let dma: DMA
    
    let dmaChannel: UnsafeMutablePointer<DMAChannel>
    
    let controlBlockBusAddress: Int
    var controlBlock: UnsafeMutablePointer<DMAControlBlock>
    var controlBlockIndex = 0
    
    let dataBusAddress: Int
    var data: UnsafeMutablePointer<Int>
    var dataIndex = 0

    public init(raspberryPi: RaspberryPi) throws {
        self.raspberryPi = raspberryPi
        
        gpio = try GPIO.on(raspberryPi)
        clock = try Clock.pwm(on: raspberryPi)
        pwm = try PWM.on(raspberryPi)
        dma = try DMA.on(raspberryPi)

        dmaChannel = dma.channel[dmaChannelNumber]
        
        // Allocate control block and data regions
        let (controlBlockBusAddress, controlBlockPointer) = try raspberryPi.allocateUncachedMemory(pages: 10)
        self.controlBlockBusAddress = controlBlockBusAddress
        controlBlock = controlBlockPointer.bindMemory(to: DMAControlBlock.self, capacity: raspberryPi.pageSize / MemoryLayout<DMAControlBlock>.stride * 10)

        let (dataBusAddress, dataPointer) = try raspberryPi.allocateUncachedMemory(pages: 10)
        self.dataBusAddress = dataBusAddress
        data = dataPointer.bindMemory(to: Int.self, capacity: raspberryPi.pageSize / MemoryLayout<Int>.stride * 10)
        
        print("ControlBlocks at 0x" + String(raspberryPi.physicalAddressOfUncachedMemory(forBusAddress: controlBlockBusAddress), radix: 16))
        print("         Data at 0x" + String(raspberryPi.physicalAddressOfUncachedMemory(forBusAddress: dataBusAddress), radix: 16))

    }
    
    public func setup() {
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
        pwm.pointee.control.insert(.clearFifo)
        
        dma.enable.pointee |= 1 << dmaChannelNumber
        usleep(100)
        dmaChannel.pointee.controlStatus.insert(.abort)
        usleep(100)
        dmaChannel.pointee.reset()
        
        // Set the PWM clock.
        clock.pointee.disable()
        clock.pointee.control = clockSource
        clock.pointee.divisor = clockDivisor
        clock.pointee.enable()
        
        // Enable DMA on the PWM.
        pwm.pointee.dmaConfiguration = [ .enabled, .dreqThreshold(1), .panicThreshold(1) ]
        
        // Enable PWM1 in serializer mode, using the FIFO as a source.
        pwm.pointee.control = [ .channel1UseFifo, .channel1SerializerMode, .channel1Enable ]
        
        print("Pumping FIFO", terminator: "")
        while !pwm.pointee.status.contains(.fifoFull) {
            print(".", terminator: "")
            pwm.pointee.fifoInput = 0
        }
        print("")
        
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(10), execute: watchdog)
        watchdog()
    }
    
    func watchdog() {
        if pwm.pointee.status.contains(.busError) {
            // Always seems to be set, and doesn't go away *shrug*
            //print("PWM Bus Error")
            pwm.pointee.status.insert(.busError)
        }

        if pwm.pointee.status.contains(.fifoReadError) {
            print("PWM FIFO Read Error")
            pwm.pointee.status.insert(.fifoReadError)
        }

        if pwm.pointee.status.contains(.fifoWriteError) {
            print("PWM FIFO Write Error")
            pwm.pointee.status.insert(.fifoWriteError)
        }
        
        if pwm.pointee.status.contains(.channel1GapOccurred) {
            print("PWM Channel 1 Gap Occurred")
            pwm.pointee.status.insert(.channel1GapOccurred)
        }

        if pwm.pointee.status.contains(.fifoEmpty) {
            // Doesn't seem to be an issue, unless maybe we get a gap as above?
            //print("PWM FIFO Empty")
        }

        
        if dmaChannel.pointee.controlStatus.contains(.errorDetected) {
            print("DMA Channel \(dmaChannelNumber) Error Detected:")
        }
    
        if dmaChannel.pointee.debug.contains(.readError) {
            print("DMA Channel \(dmaChannelNumber) Read Error")
            dmaChannel.pointee.debug.insert(.readError)
        }

        if dmaChannel.pointee.debug.contains(.fifoError) {
            print("DMA Channel \(dmaChannelNumber) FIFO Error")
            dmaChannel.pointee.debug.insert(.fifoError)
        }

        if dmaChannel.pointee.debug.contains(.readLastNotSetError) {
            print("DMA Channel \(dmaChannelNumber) Read Last Not Set Error")
            dmaChannel.pointee.debug.insert(.readLastNotSetError)
        }

        
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(10), execute: watchdog)
    }
    
    @discardableResult func addData(_ words: [Int]) -> Int {
        for (index, value) in words.enumerated() {
            data[dataIndex + index] = value
        }
        
        if controlBlockIndex > 0 {
            controlBlock[controlBlockIndex - 1].nextControlBlockAddress = controlBlockBusAddress + MemoryLayout<DMAControlBlock>.stride * controlBlockIndex
        }
        
        controlBlock[controlBlockIndex].transferInformation = [ .noWideBursts, .peripheralMapping(.pwm), .sourceAddressIncrement, .destinationDREQ, .waitForWriteResponse ]
        controlBlock[controlBlockIndex].sourceAddress = dataBusAddress + MemoryLayout<Int>.stride * dataIndex
        controlBlock[controlBlockIndex].destinationAddress = raspberryPi.peripheralBusBaseAddress + PWM.offset + PWM.fifoInputOffset
        controlBlock[controlBlockIndex].transferLength = MemoryLayout<Int>.stride * words.count
        controlBlock[controlBlockIndex].tdModeStride = 0
        controlBlock[controlBlockIndex].nextControlBlockAddress = 0
        
        dataIndex += words.count
        controlBlockIndex += 1
        
        return controlBlockIndex - 1
    }

    @discardableResult func addRange(_ range: Int) -> Int {
        data[dataIndex] = range
        
        if controlBlockIndex > 0 {
            controlBlock[controlBlockIndex - 1].nextControlBlockAddress = controlBlockBusAddress + MemoryLayout<DMAControlBlock>.stride * controlBlockIndex
        }
        
        controlBlock[controlBlockIndex].transferInformation = [ .noWideBursts, .peripheralMapping(.pwm), .destinationDREQ, .waitForWriteResponse ]
        controlBlock[controlBlockIndex].sourceAddress = dataBusAddress + MemoryLayout<Int>.stride * dataIndex
        controlBlock[controlBlockIndex].destinationAddress = raspberryPi.peripheralBusBaseAddress + PWM.offset + PWM.channel1RangeOffset
        controlBlock[controlBlockIndex].transferLength = MemoryLayout<Int>.stride
        controlBlock[controlBlockIndex].tdModeStride = 0
        controlBlock[controlBlockIndex].nextControlBlockAddress = 0
        
        dataIndex += 1
        controlBlockIndex += 1
        
        return controlBlockIndex - 1
    }

    @discardableResult func addGpio(pin: Int, value: Bool) -> Int {
        data[dataIndex] = 1 << pin
        
        if controlBlockIndex > 0 {
            controlBlock[controlBlockIndex - 1].nextControlBlockAddress = controlBlockBusAddress + MemoryLayout<DMAControlBlock>.stride * controlBlockIndex
        }
        
        controlBlock[controlBlockIndex].transferInformation = [ .noWideBursts, .peripheralMapping(.pwm), .destinationDREQ, .waitForWriteResponse ]
        controlBlock[controlBlockIndex].sourceAddress = dataBusAddress + MemoryLayout<Int>.stride * dataIndex
        controlBlock[controlBlockIndex].destinationAddress = raspberryPi.peripheralBusBaseAddress + GPIO.offset + (value ? GPIO.outputSetOffset : GPIO.outputClearOffset)
        controlBlock[controlBlockIndex].transferLength = MemoryLayout<Int>.stride
        controlBlock[controlBlockIndex].tdModeStride = 0
        controlBlock[controlBlockIndex].nextControlBlockAddress = 0
        
        dataIndex += 1
        controlBlockIndex += 1
        
        return controlBlockIndex - 1
    }
    
    func dueDelayedEvents(_ delayedEvents: inout [(Int, BitstreamEvent)]) -> [BitstreamEvent] {
        let oldDelayedEvents = delayedEvents
        delayedEvents.removeAll()
        
        var dueEvents: [BitstreamEvent] = []

        for (delay, event) in oldDelayedEvents {
            if delay == 1 {
                dueEvents.append(event)
            } else {
                delayedEvents.append((delay - 1, event))
            }
        }
        
        return dueEvents
    }
    
    func leftPad(_ string: String, toLength length: Int, withPad pad: String) -> String {
        if string.characters.count < length {
            return String(repeating: pad, count: length - string.characters.count) + string
        } else {
            return string
        }
    }
    
    func printWords(_ words: [Int], wordSize: Int, lastWordSize: Int) {
        for (index, word) in words.enumerated() {
            if index > 0 { print("            ", terminator: "") }
            let size = index == words.count - 1 ? lastWordSize : wordSize

            var string = leftPad(String(UInt(bitPattern: word), radix: 2), toLength: 32, withPad: "0")
            if string.characters.count > size {
                string = string.substring(to: string.index(string.startIndex, offsetBy: size))
            }
            
            let wordStr = stride(from: 0, to: string.characters.count, by: 8).map { i -> String in
                let startIndex = string.index(string.startIndex, offsetBy: i)
                let endIndex   = string.index(startIndex, offsetBy: 8, limitedBy: string.endIndex) ?? string.endIndex
                return string[startIndex..<endIndex]
                }.joined(separator: " ")
            print(wordStr)
        }
    }
    
    public func queue(bitstream: Bitstream) throws -> Int {
        let startIndex = controlBlockIndex

        var range = 0
        var words: [Int] = []
        var delayedEvents: [(Int, BitstreamEvent)] = []
        var addresses: [Int: Int] = [:]
        
        var repeating = false
        loop: repeat {
            var laggingEvents = delayedEvents
            delayedEvents = []
            
            var dataIndex = 0
            for event in bitstream {
                switch event {
                case let .data(word: word, size: size):
                    if repeating && laggingEvents.isEmpty && words.isEmpty,
                        let address = addresses[dataIndex]
                    {
                        print("            --> \(dataIndex): \(address)")
                        controlBlock[controlBlockIndex - 1].nextControlBlockAddress = controlBlockBusAddress + MemoryLayout<DMAControlBlock>.stride * address
                        break loop
                    }
                    
                    words.append(word)

                    var dueEvents: [BitstreamEvent] = []
                    dueEvents.append(contentsOf: dueDelayedEvents(&laggingEvents))
                    dueEvents.append(contentsOf: dueDelayedEvents(&delayedEvents))
                    
                    if size != range || !dueEvents.isEmpty {
                        let rootIndex = dataIndex - words.count + 1
                        addresses[rootIndex] = addData(words)
                        print(leftPad(String(rootIndex), toLength: 2, withPad: " ") + ": " +
                            leftPad(String(addresses[rootIndex]!), toLength: 4, withPad: " ") + " -> ", terminator: "")
                        printWords(words, wordSize: range, lastWordSize: size)
                        words = []
                    }
                
                    if size != range {
                        let address = addRange(size)
                        print(leftPad(String(address), toLength: 8, withPad: " ") + " -> Range \(size)")
                        range = size
                    }

                    for event in dueEvents {
                        switch event {
                        case .railComCutoutStart:
                            let address = addGpio(pin: railcomGpio, value: false)
                            print(leftPad(String(address), toLength: 8, withPad: " ") + " -> Railcom ↓")
                        case .railComCutoutEnd:
                            let address = addGpio(pin: railcomGpio, value: true)
                            print(leftPad(String(address), toLength: 8, withPad: " ") + " -> Railcom ↑")
                        case .debugStart:
                            let address = addGpio(pin: debugGpio, value: true)
                            print(leftPad(String(address), toLength: 8, withPad: " ") + " -> Debug ↑")
                        case .debugEnd:
                            let address = addGpio(pin: debugGpio, value: false)
                            print(leftPad(String(address), toLength: 8, withPad: " ") + " -> Debug ↓")
                        default:
                            assertionFailure("Unknown event")
                        }
                    }
                    
                    dataIndex += 1
                default:
                    delayedEvents.append((eventDelay, event))
                }
            }
            
            if repeating {
                throw DriverError.infiniteLoop
            } else {
                repeating = true
            }
        } while !delayedEvents.isEmpty

        if !words.isEmpty {
            let address = addData(words)
            print(leftPad(String(address), toLength: 8, withPad: " ") + " -> \(startIndex)", terminator: "")
            printWords(words, wordSize: range, lastWordSize: range)
            print("            --> Start")
            controlBlock[controlBlockIndex - 1].nextControlBlockAddress = controlBlockBusAddress + MemoryLayout<DMAControlBlock>.stride * startIndex
        }
        
        return startIndex
    }
    
    public func start(at index: Int) {
        dmaChannel.pointee.controlBlockAddress = controlBlockBusAddress + MemoryLayout<DMAControlBlock>.stride * index

        usleep(100)
        dmaChannel.pointee.controlStatus = [ .waitForOutstandingWrites, .priorityLevel(8), .panicPriorityLevel(8), .active ]
        
        while !dmaChannel.pointee.controlStatus.contains(.transferComplete) { }
    }
    
    public func stop() {
        pwm.pointee.disable()
        dmaChannel.pointee.controlStatus.insert(.abort)
        usleep(100)
        dmaChannel.pointee.reset()
        clock.pointee.disable()
        
        gpio.pointee.functionSelect[dccGpio] = .output
        
        gpio.pointee.outputClear[railcomGpio] = true
        gpio.pointee.outputClear[debugGpio] = true
        gpio.pointee.outputClear[dccGpio] = true
    }
    
}
