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
    
    static let selfTransferInformation: DMATransferInformation = [ .sourceIgnoreWrites ]
    static let pwmFifoTransferInformation: DMATransferInformation = [ .noWideBursts, .peripheralMapping(.pwm), .sourceAddressIncrement, .destinationDREQ, .waitForWriteResponse ]
    static let pwmRangeTransferInformation: DMATransferInformation = [ .noWideBursts, .peripheralMapping(.pwm), .destinationDREQ, .waitForWriteResponse ]

    func offsetOfControlBlock(at index: Int) -> Int {
        return MemoryLayout<DMAControlBlock>.stride * index
    }
    
    func offsetOfData(at index: Int) -> Int {
        return MemoryLayout<Int>.stride * index
    }
    
    func parseBitstream(_ bitstream: Bitstream) -> (controlBlocks: [DMAControlBlock], data: [Int]) {
        var controlBlocks: [DMAControlBlock] = []
        var data: [Int] = []
        
        let pwmFifoDestinationAddress = raspberryPi.peripheralBusAddress + PWM.offset + PWM.fifoInputOffset
        let pwmChannel1RangeDestinationAddress = raspberryPi.peripheralBusAddress + PWM.offset + PWM.channel1RangeOffset
        
        // The start control block is used to determine when the DMA engine is operating on this bitstream, so we can free the memory of the prior one. It simply points to the next control block in the chain, and zeros its own next control block address as a signal that it's begun.
        controlBlocks.append(DMAControlBlock(
            transferInformation: Driver.selfTransferInformation,
            sourceAddress: 0,
            destinationAddress: offsetOfControlBlock(at: 0) + DMAControlBlock.nextControlBlockOffset,
            transferLength: MemoryLayout<Int>.stride,
            tdModeStride: 0,
            nextControlBlockAddress: offsetOfControlBlock(at: 1)))
        
        for event in bitstream {
            switch event {
            case let .data(word: word, size: size):
                controlBlocks.append(DMAControlBlock(
                    transferInformation: Driver.pwmFifoTransferInformation,
                    sourceAddress: offsetOfData(at: data.count),
                    destinationAddress: pwmFifoDestinationAddress,
                    transferLength: MemoryLayout<Int>.stride,
                    tdModeStride: 0,
                    nextControlBlockAddress: offsetOfControlBlock(at: controlBlocks.count + 1)))
                data.append(word)
                
                controlBlocks.append(DMAControlBlock(
                    transferInformation: Driver.pwmRangeTransferInformation,
                    sourceAddress: offsetOfData(at: data.count),
                    destinationAddress: pwmChannel1RangeDestinationAddress,
                    transferLength: MemoryLayout<Int>.stride,
                    tdModeStride: 0,
                    nextControlBlockAddress: offsetOfControlBlock(at: controlBlocks.count + 1)))
                data.append(size)
            default:
                fatalError()
            }
        }
        
        // The final control block is used to determine when the DMA engine has completed at least one full broadcast of this bitstream, before looping. It points to the first control block in the loop, after zeroing the entire first control block (which is otherwise unused) as a signal that broadcast has completed.
        controlBlocks.append(DMAControlBlock(
            transferInformation: Driver.selfTransferInformation,
            sourceAddress: 0,
            destinationAddress: offsetOfControlBlock(at: 0),
            transferLength: MemoryLayout<DMAControlBlock>.stride,
            tdModeStride: 0,
            nextControlBlockAddress: offsetOfControlBlock(at: 1)))
        
        return (controlBlocks, data)
    }
    
    public func queue(_ bitstream: Bitstream) throws {
        var (controlBlocks, data) = parseBitstream(bitstream)
        
        let controlBlocksSize = MemoryLayout<DMAControlBlock>.stride * controlBlocks.count
        let dataSize = MemoryLayout<Int>.stride * data.count
        
        let memory = try raspberryPi.allocateUncachedMemory(minimumSize: controlBlocksSize + dataSize)
        
        for (index, controlBlock) in controlBlocks.enumerated() {
            if controlBlock.sourceAddress < raspberryPi.peripheralBusAddress && !controlBlock.transferInformation.contains(.sourceIgnoreWrites) {
                controlBlocks[index].sourceAddress += memory.busAddress + controlBlocksSize
            }
            if controlBlock.destinationAddress < raspberryPi.peripheralBusAddress && !controlBlock.transferInformation.contains(.destinationWidthWide) {
                controlBlocks[index].destinationAddress += memory.busAddress + controlBlocksSize
            }
            controlBlocks[index].nextControlBlockAddress += memory.busAddress
        }
        
        memory.pointer.bindMemory(to: DMAControlBlock.self, capacity: controlBlocks.count).initialize(from: controlBlocks)
        memory.pointer.advanced(by: controlBlocksSize).bindMemory(to: Int.self, capacity: data.count).initialize(from: data)

        // memory.busAddress
    }
    
}
