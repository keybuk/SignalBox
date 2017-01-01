//
//  Driver.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/30/16.
//
//

import RaspberryPi


// Bitstream -> [DMAControlBlock] + [Int] -> allocate UCM and copy into

struct Driver {
    
    let raspberryPi: RaspberryPi
    
    init(raspberryPi: RaspberryPi) {
        self.raspberryPi = raspberryPi
    }
    
    static let pwmFifoTransferInformation: DMATransferInformation = [ .noWideBursts, .peripheralMapping(.pwm), .sourceAddressIncrement, .destinationDREQ, .waitForWriteResponse ]
    static let pwmRangeTransferInformation: DMATransferInformation = [ .noWideBursts, .peripheralMapping(.pwm), .destinationDREQ, .waitForWriteResponse ]
    
    func parseBitstream(_ bitstream: Bitstream) -> (controlBlocks: [DMAControlBlock], data: [Int]) {
        var controlBlocks: [DMAControlBlock] = []
        var data: [Int] = []
        
        for event in bitstream {
            switch event {
            case let .data(word: word, size: size):
                
                if controlBlocks.count > 0 {
                    controlBlocks[controlBlocks.count - 1].nextControlBlockAddress = MemoryLayout<DMAControlBlock>.stride * controlBlocks.count
                }

                controlBlocks.append(DMAControlBlock(
                    transferInformation: Driver.pwmFifoTransferInformation,
                    sourceAddress: MemoryLayout<Int>.stride * data.count,
                    destinationAddress: raspberryPi.peripheralBusAddress + PWM.offset + PWM.fifoInputOffset,
                    transferLength: MemoryLayout<Int>.size,
                    tdModeStride: 0,
                    nextControlBlockAddress: 0))
                data.append(word)
                
                if controlBlocks.count > 0 {
                    controlBlocks[controlBlocks.count - 1].nextControlBlockAddress = MemoryLayout<DMAControlBlock>.stride * controlBlocks.count
                }

                controlBlocks.append(DMAControlBlock(
                    transferInformation: Driver.pwmRangeTransferInformation,
                    sourceAddress: MemoryLayout<Int>.stride * data.count,
                    destinationAddress: raspberryPi.peripheralBusAddress + PWM.offset + PWM.channel1RangeOffset,
                    transferLength: MemoryLayout<Int>.size,
                    tdModeStride: 0,
                    nextControlBlockAddress: 0))
                data.append(size)
            default:
                fatalError()
            }
        }
        
        return (controlBlocks, data)
    }
    
    public func queue(_ bitstream: Bitstream) throws {
        var (controlBlocks, data) = parseBitstream(bitstream)
        
        let controlBlocksSize = MemoryLayout<DMAControlBlock>.stride * controlBlocks.count
        let dataSize = MemoryLayout<Int>.stride * data.count
        
        let memory = try raspberryPi.allocateUncachedMemory(minimumSize: controlBlocksSize + dataSize)
        
        for (index, controlBlock) in controlBlocks.enumerated() {
            if controlBlock.sourceAddress < raspberryPi.peripheralBusAddress {
                controlBlocks[index].sourceAddress += memory.busAddress + controlBlocksSize
            }
            if controlBlock.destinationAddress < raspberryPi.peripheralBusAddress {
                controlBlocks[index].destinationAddress += memory.busAddress + controlBlocksSize
            }
            controlBlocks[index].nextControlBlockAddress += memory.busAddress
        }
        
        memory.pointer.bindMemory(to: DMAControlBlock.self, capacity: controlBlocks.count).initialize(from: controlBlocks)
        memory.pointer.advanced(by: controlBlocksSize).bindMemory(to: Int.self, capacity: data.count).initialize(from: data)

        // memory.busAddress
    }
    
}
