//
//  DMATests.swift
//  RaspberryPiTests
//
//  Created by Scott James Remnant on 6/8/18.
//

import XCTest

@testable import RaspberryPi

class DMALayoutTests : XCTestCase {

    // MARK: Layout

    /// Test that the layout of the Registers struct matches hardware.
    func testRegistersLayout() {
        XCTAssertEqual(MemoryLayout<DMA.Registers>.size, 0x24)
        XCTAssertEqual(MemoryLayout<DMAControlStatus>.size, 0x04)
        XCTAssertEqual(MemoryLayout<DMATransferInformation>.size, 0x04)
        XCTAssertEqual(MemoryLayout<DMADebug>.size, 0x04)

        #if swift(>=4.1.9)
        XCTAssertEqual(MemoryLayout.offset(of: \DMA.Registers.controlStatus), 0x00)
        XCTAssertEqual(MemoryLayout.offset(of: \DMA.Registers.controlBlockAddress), 0x04)
        XCTAssertEqual(MemoryLayout.offset(of: \DMA.Registers.transferInformation), 0x08)
        XCTAssertEqual(MemoryLayout.offset(of: \DMA.Registers.sourceAddress), 0x0c)
        XCTAssertEqual(MemoryLayout.offset(of: \DMA.Registers.destinationAddress), 0x10)
        XCTAssertEqual(MemoryLayout.offset(of: \DMA.Registers.transferLength), 0x14)
        XCTAssertEqual(MemoryLayout.offset(of: \DMA.Registers.stride), 0x18)
        XCTAssertEqual(MemoryLayout.offset(of: \DMA.Registers.nextControlBlockAddress), 0x1c)
        XCTAssertEqual(MemoryLayout.offset(of: \DMA.Registers.debug), 0x20)
        #endif

        XCTAssertEqual(MemoryLayout<DMABitField>.size, 0x04)
    }

}


class DMATests : XCTestCase {

    var registers: ContiguousArray<DMA.Registers> = []
    var pointers: [UnsafeMutablePointer<DMA.Registers>] = []
    var interruptStatusRegister = DMABitField()
    var enableRegister = DMABitField()

    var dma: DMA!

    override func setUp() {
        registers = ContiguousArray(repeating: DMA.Registers(), count: DMA.count)
        pointers = registers.indices.map({ UnsafeMutablePointer(&registers[$0]) })
        interruptStatusRegister = DMABitField()
        enableRegister = DMABitField()
        dma = DMA(registers: pointers, interruptStatusRegister: &interruptStatusRegister, enableRegister: &enableRegister)
    }

    override func tearDown() {
        dma = nil
        pointers.removeAll()
        registers.removeAll()
    }

    
    /// Test that a modification to the first channel goes to the first set of registers.
    func testFirstChannel() {
        dma[0].reset()

        XCTAssertNotEqual(registers[0].controlStatus.rawValue, 0)
    }

    /// Test that a modification to the last channel goes to the last set of registers.
    func testLastChannel() {
        dma[15].reset()

        XCTAssertNotEqual(registers[15].controlStatus.rawValue, 0)
    }


    // MARK: isEnabled

    /// Test that we can enable a DMA channel.
    func testSetIsEnabled() {
        dma[0].isEnabled = true

        XCTAssertEqual(enableRegister.field & 1, 1)
    }

    /// Test that we can disable a DMA channel.
    func testClearIsEnabled() {
        // Corrupt the field so we can see it go to zero.
        enableRegister.field = ~0

        dma[0].isEnabled = false

        XCTAssertEqual(enableRegister.field & 1, 0)
    }

    /// Test that we can get the status of an enabled DMA channel.
    func testGetIsEnabled() {
        enableRegister.field = 1

        XCTAssertEqual(dma[0].isEnabled, true)
    }

    /// Test that the default status of a DMA channel is disabled.
    func testDefaultIsEnabled() {
        XCTAssertEqual(dma[0].isEnabled, false)
    }


    // MARK: interruptStatus

    /// Test that we can get the interrupt status of an DMA channel.
    func testGetInterruptStatus() {
        interruptStatusRegister.field = 1

        XCTAssertEqual(dma[0].interruptStatus, true)
    }

    /// Test that the default interrupt status of a DMA channel is false.
    func testDefaultInterruptStatus() {
        XCTAssertEqual(dma[0].interruptStatus, false)
    }


    // MARK: reset

    /// Test that we can reset a DMA channel.
    func testReset() {
        dma[0].reset()

        XCTAssertEqual((registers[0].controlStatus.rawValue >> 31) & 1, 1)
    }


    /// MARK: abort

    /// Test that we can abort a DMA transfer.
    func testAbort() {
        dma[0].abort()

        XCTAssertEqual((registers[0].controlStatus.rawValue >> 30) & 1, 1)
    }
    
    
    // MARK: isDebugPauseDisabled
    
    /// Test that we can set the debugPauseDisabled bit of the control/status register.
    func testSetDisableDebugPause() {
        dma[0].disableDebugPause = true
        
        XCTAssertEqual((registers[0].controlStatus.rawValue >> 29) & 1, 1)
    }

    /// Test that we can clear the debugPauseDisabled bit of the control/status register.
    func testClearDisableDebugPause() {
        registers[0].controlStatus = DMAControlStatus(rawValue: ~0)
        
        dma[0].disableDebugPause = false
        
        XCTAssertEqual((registers[0].controlStatus.rawValue >> 29) & 1, 0)
    }
    
    /// Test that we can test for the debugPauseDisabled bit of the control/status register.
    func testGetDisableDebugPause() {
        registers[0].controlStatus = DMAControlStatus(rawValue: 1 << 29)
        
        XCTAssertEqual(dma[0].disableDebugPause, true)
    }

    /// Test that the default is false when the debugPauseDisabled bit of the control/status register is not set.
    func testDefaultDisableDebugPause() {
        XCTAssertEqual(dma[0].disableDebugPause, false)
    }

    
    // MARK: waitForOutstandingWrites
    
    /// Test that we can set the waitForOutstandingWrites bit of the control/status register.
    func testSetWaitForOutstandingWrites() {
        dma[0].waitForOutstandingWrites = true
        
        XCTAssertEqual((registers[0].controlStatus.rawValue >> 28) & 1, 1)
    }
    
    /// Test that we can clear the waitForOutstandingWrites bit of the control/status register.
    func testClearWaitForOutstandingWrites() {
        registers[0].controlStatus = DMAControlStatus(rawValue: ~0)
        
        dma[0].waitForOutstandingWrites = false
        
        XCTAssertEqual((registers[0].controlStatus.rawValue >> 28) & 1, 0)
    }
    
    /// Test that we can test for the waitForOutstandingWrites bit of the control/status register.
    func testGetWaitForOutstandingWrites() {
        registers[0].controlStatus = DMAControlStatus(rawValue: 1 << 28)
        
        XCTAssertEqual(dma[0].waitForOutstandingWrites, true)
    }
    
    /// Test that the default is false when the waitForOutstandingWrites bit of the control/status register is not set.
    func testDefaultWaitForOutstandingWrites() {
        XCTAssertEqual(dma[0].waitForOutstandingWrites, false)
    }
    
    
    // MARK: panicPriorityLevel
    
    /// Test that we can set the panicPriorityLevel bits of the control/status register.
    func testSetPanicPriorityLevel() {
        dma[0].panicPriorityLevel = 7
        
        XCTAssertEqual((registers[0].controlStatus.rawValue >> 20) & ~(~0 << 4), 7)
    }
    
    /// Test that when we set the panicPriorityLevel bits, all are cleared.
    func testPanicPriorityLevelIdempotent() {
        // Corrupt the bits of the register.
        registers[0].controlStatus = DMAControlStatus(rawValue: ~0)

        dma[0].panicPriorityLevel = 3
        
        XCTAssertEqual((registers[0].controlStatus.rawValue >> 20) & ~(~0 << 4), 3)
    }
    
    /// Test that when we set the panicPriorityLevel bits, all other bits are left alone.
    func testPanicPriorityLevelDiscrete() {
        // Corrupt the bits of the register.
        registers[0].controlStatus = DMAControlStatus(rawValue: ~0)
        
        dma[0].panicPriorityLevel = 3
        
        XCTAssertEqual(registers[0].controlStatus.rawValue | (~(~0 << 4) << 20), ~0)
    }

    /// Test that we can get the panicPriorityLevel bits of the control/status register.
    func testGetPanicPriorityLevel() {
        registers[0].controlStatus = DMAControlStatus(rawValue: 9 << 20)

        XCTAssertEqual(dma[0].panicPriorityLevel, 9)
    }
    
    
    // MARK: priorityLevel
    
    /// Test that we can set the priorityLevel bits of the control/status register.
    func testSetPriorityLevel() {
        dma[0].priorityLevel = 7
        
        XCTAssertEqual((registers[0].controlStatus.rawValue >> 16) & ~(~0 << 4), 7)
    }
    
    /// Test that when we set the priorityLevel bits, all are cleared.
    func testPriorityLevelIdempotent() {
        // Corrupt the bits of the register.
        registers[0].controlStatus = DMAControlStatus(rawValue: ~0)
        
        dma[0].priorityLevel = 3
        
        XCTAssertEqual((registers[0].controlStatus.rawValue >> 16) & ~(~0 << 4), 3)
    }
    
    /// Test that when we set the priorityLevel bits, all other bits are left alone.
    func testPriorityLevelDiscrete() {
        // Corrupt the bits of the register.
        registers[0].controlStatus = DMAControlStatus(rawValue: ~0)
        
        dma[0].priorityLevel = 3
        
        XCTAssertEqual(registers[0].controlStatus.rawValue | (~(~0 << 4) << 16), ~0)
    }
    
    /// Test that we can get the priorityLevel bits of the control/status register.
    func testGetPriorityLevel() {
        registers[0].controlStatus = DMAControlStatus(rawValue: 9 << 16)
        
        XCTAssertEqual(dma[0].priorityLevel, 9)
    }
    
    
    // MARK: isErrorDetected
    
    /// Test that we can test for the errorDetected bit of the control/status register.
    func testGetIsErrorDetected() {
        registers[0].controlStatus = DMAControlStatus(rawValue: 1 << 8)
        
        XCTAssertEqual(dma[0].isErrorDetected, true)
    }
    
    /// Test that the default is false when the errorDetected bit of the control/status register is not set.
    func testDefaultIsErrorDetected() {
        XCTAssertEqual(dma[0].isErrorDetected, false)
    }
    
    
    // MARK: isWaitingForOutstandingWrites
    
    /// Test that we can test for the waitingForOutstandingWrites bit of the control/status register.
    func testGetWaitingForOutstandingWrites() {
        registers[0].controlStatus = DMAControlStatus(rawValue: 1 << 6)
        
        XCTAssertEqual(dma[0].isWaitingForOutstandingWrites, true)
    }
    
    /// Test that the default is false when the waitingForOutstandingWrites bit of the control/status register is not set.
    func testDefaultWaitingForOutstandingWrites() {
        XCTAssertEqual(dma[0].isWaitingForOutstandingWrites, false)
    }
    
    
    // MARK: isPausedByDataRequest
    
    /// Test that we can test for the pausedByDataRequest bit of the control/status register.
    func testGetIsPausedByDataRequest() {
        registers[0].controlStatus = DMAControlStatus(rawValue: 1 << 5)
        
        XCTAssertEqual(dma[0].isPausedByDataRequest, true)
    }
    
    /// Test that the default is false when the pausedByDataRequest bit of the control/status register is not set.
    func testDefaultIsPausedByDataRequest() {
        XCTAssertEqual(dma[0].isPausedByDataRequest, false)
    }

    
    // MARK: isPaused
    
    /// Test that we can test for the paused bit of the control/status register.
    func testGetIsPaused() {
        registers[0].controlStatus = DMAControlStatus(rawValue: 1 << 4)
        
        XCTAssertEqual(dma[0].isPaused, true)
    }
    
    /// Test that the default is false when the paused bit of the control/status register is not set.
    func testDefaultIsPaused() {
        XCTAssertEqual(dma[0].isPaused, false)
    }

    
    // MARK: isRequestingData
    
    /// Test that we can test for the requestingData bit of the control/status register.
    func testGetIsRequestingData() {
        registers[0].controlStatus = DMAControlStatus(rawValue: 1 << 3)
        
        XCTAssertEqual(dma[0].isRequestingData, true)
    }
    
    /// Test that the default is false when the requestingData bit of the control/status register is not set.
    func testDefaultIsRequestingData() {
        XCTAssertEqual(dma[0].isRequestingData, false)
    }
    
    
    // MARK: isInterruptRaised
    
    /// Test that we can test for the interrupt bit of the control/status register.
    func testGetIsInterruptRaised() {
        registers[0].controlStatus = DMAControlStatus(rawValue: 1 << 2)
        
        XCTAssertEqual(dma[0].isInterruptRaised, true)
    }
    
    /// Test that the default is false when the interrupt bit of the control/status register is not set.
    func testDefaultIsInterruptRaised() {
        XCTAssertEqual(dma[0].isInterruptRaised, false)
    }
    
    /// Test that we can clear the status by setting to false, and that actually sets the
    /// interrupt bit of the control/status register.
    func testClearIsInterruptRaised() {
        dma[0].isInterruptRaised = false
        
        XCTAssertEqual((registers[0].controlStatus.rawValue >> 2) & 1, 1)
    }

    /// Test that setting isInterruptRaised to true is ignored.
    func testIsInterruptRaisedNoop() {
        dma[0].isInterruptRaised = true
        
        XCTAssertEqual((registers[0].controlStatus.rawValue >> 2) & 1, 0)
    }
    

    // MARK: isComplete
    
    /// Test that we can test for the transferComplete bit of the control/status register.
    func testGetIsComplete() {
        registers[0].controlStatus = DMAControlStatus(rawValue: 1 << 1)
        
        XCTAssertEqual(dma[0].isComplete, true)
    }
    
    /// Test that the default is false when the transferComplete bit of the control/status register
    /// is not set.
    func testDefaultIsComplete() {
        XCTAssertEqual(dma[0].isComplete, false)
    }
    
    /// Test that we can clear the status by setting to false, and that actually sets the
    /// transferComplete bit of the control/status register.
    func testClearIsComplete() {
        dma[0].isComplete = false
        
        XCTAssertEqual((registers[0].controlStatus.rawValue >> 1) & 1, 1)
    }
    
    /// Test that setting isComplete to true is ignored.
    func testIsCompleteNoop() {
        dma[0].isComplete = true
        
        XCTAssertEqual((registers[0].controlStatus.rawValue >> 1) & 1, 0)
    }

    
    // MARK: isActive
    
    /// Test that we can set the active bit of the control/status register.
    func testSetIsActive() {
        dma[0].isActive = true
        
        XCTAssertEqual(registers[0].controlStatus.rawValue & 1, 1)
    }
    
    /// Test that we can clear the active bit of the control/status register.
    func testClearIsActive() {
        registers[0].controlStatus = DMAControlStatus(rawValue: ~0)
        
        dma[0].isActive = false
        
        XCTAssertEqual(registers[0].controlStatus.rawValue & 1, 0)
    }
    
    /// Test that we can test for the active bit of the control/status register.
    func testGetIsActive() {
        registers[0].controlStatus = DMAControlStatus(rawValue: 1)
        
        XCTAssertEqual(dma[0].isActive, true)
    }
    
    /// Test that the default is false when the active bit of the control/status register is not set.
    func testDefaultIsActive() {
        XCTAssertEqual(dma[0].isActive, false)
    }
    
    
    // MARK: controlBlockAddress
    
    /// Test that we can set the control block address.
    func testSetControlBlockAddress() {
        dma[0].controlBlockAddress = 0xcafe0000
        
        XCTAssertEqual(registers[0].controlBlockAddress, 0xcafe0000)
    }
    
    /// Test that we can get the control block address.
    func testGetControlBlockAddress() {
        registers[0].controlBlockAddress = 0xbeef0000
        
        XCTAssertEqual(dma[0].controlBlockAddress, 0xbeef0000)
    }
    
    
    // MARK: controlBlock
    
    /// Test that a DMAControlBlock is synthesized from the registers that contain its data.
    func testGetControlBlock() {
        registers[0].controlBlockAddress = 0xdead0000
        registers[0].transferInformation = DMATransferInformation(rawValue: 0xbeefcafe)
        registers[0].sourceAddress = 0xc0ffee99
        registers[0].destinationAddress = 0x0ddba11
        registers[0].transferLength = 0xca11ab1e
        registers[0].stride = 0xf005ba11
        registers[0].nextControlBlockAddress = 0xbedabb1e
        
        let controlBlock = dma[0].controlBlock
        
        XCTAssertNotNil(controlBlock)
        XCTAssertEqual(controlBlock?.transferInformation, DMATransferInformation(rawValue: 0xbeefcafe))
        XCTAssertEqual(controlBlock?.sourceAddress, 0xc0ffee99)
        XCTAssertEqual(controlBlock?.destinationAddress, 0x0ddba11)
        XCTAssertEqual(controlBlock?.transferLength, 0xca11ab1e)
        XCTAssertEqual(controlBlock?.stride, 0xf005ba11)
        XCTAssertEqual(controlBlock?.nextControlBlockAddress, 0xbedabb1e)
    }

    /// Test that nil is returned for controlBlock when there is no controlBlockAddress.
    func testGetControlBlockNil() {
        registers[0].controlBlockAddress = 0
        
        XCTAssertNil(dma[0].controlBlock)
    }
    
    
    // MARK: debug fields

    /// Test that we can test for the LITE bit of the debug register.
    func testGetIsLite() {
        registers[0].debug = DMADebug(rawValue: 1 << 28)
        
        XCTAssertEqual(dma[0].isLite, true)
    }
    
    /// Test that the default is false when the LITE bit of the debug register is not set.
    func testDefaultIsLite() {
        XCTAssertEqual(dma[0].isLite, false)
    }
    
    /// Test that we can get the VERSION field of the debug register.
    func testGetVersion() {
        registers[0].debug = DMADebug(rawValue: 2 << 25)
        
        XCTAssertEqual(dma[0].version, 2)
    }
    
    /// Test that we can get the DMA_STATE field of the debug register.
    func testGetStateMachineState() {
        registers[0].debug = DMADebug(rawValue: 1 << 16)
        
        XCTAssertEqual(dma[0].stateMachineState, 1)
    }

    /// Test that we can get the DMA_ID field of the debug register.
    func testGetAxiIdentifier() {
        registers[0].debug = DMADebug(rawValue: 135 << 8)
        
        XCTAssertEqual(dma[0].axiIdentifier, 135)
    }
    
    /// Test that we can get the OUTSTANDING_WRITES field of the debug register.
    func testGetNumberOfOutstandingWrites() {
        registers[0].debug = DMADebug(rawValue: 13 << 4)
        
        XCTAssertEqual(dma[0].numberOfOutstandingWrites, 13)
    }

    // MARK: isReadError
    
    /// Test that we can test for the READ_ERROR bit of the debug register.
    func testGetIsReadError() {
        registers[0].debug = DMADebug(rawValue: 1 << 2)
        
        XCTAssertEqual(dma[0].isReadError, true)
    }
    
    /// Test that the default is false when the READ_ERROR bit of the debug register is not set.
    func testDefaultIsReadError() {
        XCTAssertEqual(dma[0].isReadError, false)
    }

    /// Test that we can clear the status by setting to false, and that actually sets the
    /// READ_ERROR bit of the control/status register.
    func testClearIsReadError() {
        dma[0].isReadError = false
        
        XCTAssertEqual((registers[0].debug.rawValue >> 2) & 1, 1)
    }
    
    /// Test that setting isReadError to true is ignored.
    func testIsReadErrorNoop() {
        dma[0].isReadError = true
        
        XCTAssertEqual((registers[0].debug.rawValue >> 2) & 1, 0)
    }

    
    // MARK: isFifoError
    
    /// Test that we can test for the FIFO_ERROR bit of the debug register.
    func testGetIsFifoError() {
        registers[0].debug = DMADebug(rawValue: 1 << 1)
        
        XCTAssertEqual(dma[0].isFifoError, true)
    }
    
    /// Test that the default is false when the FIFO_ERROR bit of the debug register is not set.
    func testDefaultIsFifoError() {
        XCTAssertEqual(dma[0].isFifoError, false)
    }

    /// Test that we can clear the status by setting to false, and that actually sets the
    /// FIFO_ERROR bit of the control/status register.
    func testClearIsFifoError() {
        dma[0].isFifoError = false
        
        XCTAssertEqual((registers[0].debug.rawValue >> 1) & 1, 1)
    }
    
    /// Test that setting isFifoError to true is ignored.
    func testIsFifoErrorNoop() {
        dma[0].isFifoError = true
        
        XCTAssertEqual((registers[0].debug.rawValue >> 1) & 1, 0)
    }

    
    // MARK: isReadLastNotSetError
    /// Test that we can test for the READ_LAST_NOT_SET_ERROR bit of the debug register.
    func testGetIsReadLastNotSetError() {
        registers[0].debug = DMADebug(rawValue: 1)
        
        XCTAssertEqual(dma[0].isReadLastNotSetError, true)
    }
    
    /// Test that the default is false when the READ_LAST_NOT_SET_ERROR bit of the debug register is not set.
    func testDefaultIsReadLastNotSetError() {
        XCTAssertEqual(dma[0].isReadLastNotSetError, false)
    }

    /// Test that we can clear the status by setting to false, and that actually sets the
    /// READ_LAST_NOT_SET_ERROR bit of the control/status register.
    func testClearIsReadLastNotSetError() {
        dma[0].isReadLastNotSetError = false
        
        XCTAssertEqual(registers[0].debug.rawValue & 1, 1)
    }
    
    /// Test that setting isReadLastNotSetError to true is ignored.
    func testIsReadLastNotSetErrorNoop() {
        dma[0].isReadLastNotSetError = true
        
        XCTAssertEqual(registers[0].debug.rawValue & 1, 0)
    }

}
