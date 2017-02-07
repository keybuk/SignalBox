//
//  Support.swift
//  SignalBox
//
//  Created by Scott James Remnant on 2/3/17.
//
//

@testable import RaspberryPi


class TestMemory : MemoryRegion {
    
    let pointer: UnsafeMutableRawPointer
    let busAddress: Int
    let size: Int
    
    init(size: Int) {
        pointer = UnsafeMutableRawPointer.allocate(bytes: size, alignedTo: MemoryLayout<DMAControlBlock>.alignment)
        busAddress = Int(bitPattern: pointer)
        self.size = size
    }
    
    deinit {
        pointer.deallocate(bytes: size, alignedTo: MemoryLayout<DMAControlBlock>.alignment)
    }
    
}

class TestRaspberryPi : RaspberryPi {
    
    override func allocateUncachedMemory(minimumSize: Int) throws -> MemoryRegion {
        // Don't use the GPU memory for testing for a few reasons:
        //  1. we don't want to run tests as root.
        //  2. failing tests won't necessarily give it back.
        //  3. tests should work on macOS.
        let size = pageSize * (((minimumSize - 1) / pageSize) + 1)
        
        return TestMemory(size: size)
    }
    
}

