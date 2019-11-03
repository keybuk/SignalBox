//
//  DMAControlBlockTests.swift
//  RaspberryPiTests
//
//  Created by Scott James Remnant on 6/9/18.
//

import XCTest

import RaspberryPi

class DMAControlBlockTests : XCTestCase {

    // MARK: Layout

    /// Test that the layout of the Registers struct matches hardware.
    func testRegistersLayout() {
        XCTAssertEqual(MemoryLayout<DMAControlBlock>.size, 0x20)
        XCTAssertEqual(MemoryLayout<DMATransferInformation>.size, 0x04)

        #if swift(>=4.1.5)
        XCTAssertEqual(MemoryLayout.offset(of: \DMAControlBlock.transferInformation), 0x00)
        XCTAssertEqual(MemoryLayout.offset(of: \DMAControlBlock.sourceAddress), 0x04)
        XCTAssertEqual(MemoryLayout.offset(of: \DMAControlBlock.destinationAddress), 0x08)
        XCTAssertEqual(MemoryLayout.offset(of: \DMAControlBlock.transferLength), 0x0c)
        XCTAssertEqual(MemoryLayout.offset(of: \DMAControlBlock.stride), 0x10)
        XCTAssertEqual(MemoryLayout.offset(of: \DMAControlBlock.nextControlBlockAddress), 0x14)
        #endif
    }


    // MARK: sourceIgnoreReads
    
    /// Test that we can set sourceIgnoreReads, which sets the SRC_IGNORE bit of the transfer information.
    func testSetSourceIgnoreReads() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.sourceIgnoreReads = true
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 11) & 1, 1)
    }
    
    /// Test that we can clear sourceIgnoreReads, which removes the SRC_IGNORE bit from the transfer information.
    func testClearSourceIgnoreReads() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: ~0)
        
        controlBlock.sourceIgnoreReads = false
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 11) & 1, 0)
    }
    
    /// Test that sourceIgnoreReads is true when the SRC_IGNORE bit of the transfer information is set.
    func testGetSourceIgnoreReads() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: 1 << 11)
        
        XCTAssertEqual(controlBlock.sourceIgnoreReads, true)
    }
    
    /// Test that sourceIgnoreReads defaults to false when the SRC_IGNORE bit of the transfer information is not set.
    func testDefaultSourceIgnoreReads() {
        let controlBlock = DMAControlBlock()
        
        XCTAssertEqual(controlBlock.sourceIgnoreReads, false)
    }

    
    // MARK: sourceWaitsForDataRequest
    
    /// Test that we can set sourceWaitsForDataRequest, which sets the SRC_DREQ bit of the transfer information.
    func testSetSourceWaitsForDataRequest() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.sourceWaitsForDataRequest = true
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 10) & 1, 1)
    }
    
    /// Test that we can clear sourceWaitsForDataRequest, which removes the SRC_DREQ bit from the transfer information.
    func testClearSourceWaitsForDataRequest() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: ~0)
        
        controlBlock.sourceWaitsForDataRequest = false
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 10) & 1, 0)
    }
    
    /// Test that sourceWaitsForDataRequest is true when the SRC_DREQ bit of the transfer information is set.
    func testGetSourceWaitsForDataRequest() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: 1 << 10)
        
        XCTAssertEqual(controlBlock.sourceWaitsForDataRequest, true)
    }
    
    /// Test that sourceWaitsForDataRequest defaults to false when the SRC_DREQ bit of the transfer information is not set.
    func testDefaultSourceWaitsForDataRequest() {
        let controlBlock = DMAControlBlock()
        
        XCTAssertEqual(controlBlock.sourceWaitsForDataRequest, false)
    }

    
    // MARK: sourceWideReads
    
    /// Test that we can set sourceWideReads, which sets the SRC_WIDTH bit of the transfer information.
    func testSetSourceWideReads() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.sourceWideReads = true
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 9) & 1, 1)
    }
    
    /// Test that we can clear sourceWideReads, which removes the SRC_WIDTH bit from the transfer information.
    func testClearSourceWideReads() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: ~0)
        
        controlBlock.sourceWideReads = false
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 9) & 1, 0)
    }
    
    /// Test that sourceWideReads is true when the SRC_WIDTH bit of the transfer information is set.
    func testGetSourceWideReads() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: 1 << 9)
        
        XCTAssertEqual(controlBlock.sourceWideReads, true)
    }
    
    /// Test that sourceWideReads defaults to false when the SRC_WIDTH bit of the transfer information is not set.
    func testDefaultSourceWideReads() {
        let controlBlock = DMAControlBlock()
        
        XCTAssertEqual(controlBlock.sourceWideReads, false)
    }

    
    // MARK: incrementSourceAddress
    
    /// Test that we can set incrementSourceAddress, which sets the SRC_INC bit of the transfer information.
    func testSetIncrementSourceAddress() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.incrementSourceAddress = true
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 8) & 1, 1)
    }
    
    /// Test that we can clear incrementSourceAddress, which removes the SRC_INC bit from the transfer information.
    func testClearIncrementSourceAddress() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: ~0)
        
        controlBlock.incrementSourceAddress = false
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 8) & 1, 0)
    }
    
    /// Test that incrementSourceAddress is true when the SRC_INC bit of the transfer information is set.
    func testGetIncrementSourceAddress() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: 1 << 8)
        
        XCTAssertEqual(controlBlock.incrementSourceAddress, true)
    }
    
    /// Test that incrementSourceAddress defaults to false when the SRC_INC bit of the transfer information is not set.
    func testDefaultIncrementSourceAddress() {
        let controlBlock = DMAControlBlock()
        
        XCTAssertEqual(controlBlock.incrementSourceAddress, false)
    }

    
    // MARK: destinationIgnoreWrites
    
    /// Test that we can set destinationIgnoreWrites, which sets the DEST_IGNORE bit of the transfer information.
    func testSetDestinationIgnoreWrites() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.destinationIgnoreWrites = true
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 7) & 1, 1)
    }
    
    /// Test that we can clear destinationIgnoreWrites, which removes the DEST_IGNORE bit from the transfer information.
    func testClearDestinationIgnoreWrites() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: ~0)
        
        controlBlock.destinationIgnoreWrites = false
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 7) & 1, 0)
    }
    
    /// Test that destinationIgnoreWrites is true when the DEST_IGNORE bit of the transfer information is set.
    func testGetDestinationIgnoreWrites() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: 1 << 7)
        
        XCTAssertEqual(controlBlock.destinationIgnoreWrites, true)
    }
    
    /// Test that destinationIgnoreWrites defaults to false when the DEST_IGNORE bit of the transfer information is not set.
    func testDefaultDestinationIgnoreWrites() {
        let controlBlock = DMAControlBlock()
        
        XCTAssertEqual(controlBlock.destinationIgnoreWrites, false)
    }
    
    
    // MARK: destinationWaitsForDataRequest
    
    /// Test that we can set destinationWaitsForDataRequest, which sets the DEST_DREQ bit of the transfer information.
    func testSetDestinationWaitsForDataRequest() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.destinationWaitsForDataRequest = true
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 6) & 1, 1)
    }
    
    /// Test that we can clear destinationWaitsForDataRequest, which removes the DEST_DREQ bit from the transfer information.
    func testClearDestinationWaitsForDataRequest() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: ~0)
        
        controlBlock.destinationWaitsForDataRequest = false
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 6) & 1, 0)
    }
    
    /// Test that destinationWaitsForDataRequest is true when the DEST_DREQ bit of the transfer information is set.
    func testGetDestinationWaitsForDataRequest() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: 1 << 6)
        
        XCTAssertEqual(controlBlock.destinationWaitsForDataRequest, true)
    }
    
    /// Test that destinationWaitsForDataRequest defaults to false when the DEST_DREQ bit of the transfer information is not set.
    func testDefaultDestinationWaitsForDataRequest() {
        let controlBlock = DMAControlBlock()
        
        XCTAssertEqual(controlBlock.destinationWaitsForDataRequest, false)
    }
    
    
    // MARK: destinationWideWrites
    
    /// Test that we can set destinationWideWrites, which sets the DEST_WIDTH bit of the transfer information.
    func testSetDestinationWideWrites() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.destinationWideWrites = true
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 5) & 1, 1)
    }
    
    /// Test that we can clear destinationWideWrites, which removes the DEST_WIDTH bit from the transfer information.
    func testClearDestinationWideWrites() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: ~0)
        
        controlBlock.destinationWideWrites = false
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 5) & 1, 0)
    }
    
    /// Test that destinationWideWrites is true when the DEST_WIDTH bit of the transfer information is set.
    func testGetDestinationWideWrites() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: 1 << 5)
        
        XCTAssertEqual(controlBlock.destinationWideWrites, true)
    }
    
    /// Test that destinationWideWrites defaults to false when the DEST_WIDTH bit of the transfer information is not set.
    func testDefaultDestinationWideWrites() {
        let controlBlock = DMAControlBlock()
        
        XCTAssertEqual(controlBlock.destinationWideWrites, false)
    }
    
    
    // MARK: incrementDestinationAddress
    
    /// Test that we can set incrementDestinationAddress, which sets the DEST_INC bit of the transfer information.
    func testSetIncrementDestinationAddress() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.incrementDestinationAddress = true
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 4) & 1, 1)
    }
    
    /// Test that we can clear incrementDestinationAddress, which removes the DEST_INC bit from the transfer information.
    func testClearIncrementDestinationAddress() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: ~0)
        
        controlBlock.incrementDestinationAddress = false
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 4) & 1, 0)
    }
    
    /// Test that incrementDestinationAddress is true when the DEST_INC bit of the transfer information is set.
    func testGetIncrementDestinationAddress() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: 1 << 4)
        
        XCTAssertEqual(controlBlock.incrementDestinationAddress, true)
    }
    
    /// Test that incrementDestinationAddress defaults to false when the DEST_INC bit of the transfer information is not set.
    func testDefaultIncrementDestinationAddress() {
        let controlBlock = DMAControlBlock()
        
        XCTAssertEqual(controlBlock.incrementDestinationAddress, false)
    }

    
    // MARK: noWideBursts
    
    /// Test that we can set noWideBursts, which sets the NO_WIDE_BURSTS bit of the transfer information.
    func testSetNoWideBursts() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.noWideBursts = true
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 26) & 1, 1)
    }
    
    /// Test that we can clear noWideBursts, which removes the NO_WIDE_BURSTS bit from the transfer information.
    func testClearNoWideBursts() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: ~0)
        
        controlBlock.noWideBursts = false
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 26) & 1, 0)
    }
    
    /// Test that noWideBursts is true when the NO_WIDE_BURSTS bit of the transfer information is set.
    func testGetNoWideBursts() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: 1 << 26)
        
        XCTAssertEqual(controlBlock.noWideBursts, true)
    }
    
    /// Test that noWideBursts defaults to false when the NO_WIDE_BURSTS bit of the transfer information is not set.
    func testDefaultNoWideBursts() {
        let controlBlock = DMAControlBlock()
        
        XCTAssertEqual(controlBlock.noWideBursts, false)
    }
    
    
    // MARK: waitCycles
    
    /// Test that we can get waitCycles which returns the WAITS field of the transfer information.
    func testGetWaitCycles() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.transferInformation = DMATransferInformation(rawValue: 7 << 21)
        
        XCTAssertEqual(controlBlock.waitCycles, 7)
    }
    
    /// Test that we can set waitCycles, which sets the WAITS field of the transfer information.
    func testSetWaitCycles() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.waitCycles = 9
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 21) & ~(~0 << 5), 9)
    }
    
    /// Test that when we set waitCycles, any existing bits are cleared.
    func testSetWaitCyclesIdempotent() {
        var controlBlock = DMAControlBlock()
        
        // Corrupt the field to ensure the bits are set.
        controlBlock.transferInformation = DMATransferInformation(rawValue: ~0)

        controlBlock.waitCycles = 8
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 21) & ~(~0 << 5), 8)
    }

    /// Test that when we set waitCycles, other fields are not altered.
    func testSetWaitCyclesDiscrete() {
        var controlBlock = DMAControlBlock()
        
        // Corrupt the field to ensure the bits are set.
        controlBlock.transferInformation = DMATransferInformation(rawValue: ~0)
        
        controlBlock.waitCycles = 8
        
        XCTAssertEqual(controlBlock.transferInformation.rawValue | (~(~0 << 5) << 21), ~0)
    }


    // MARK: peripheral
    
    /// Test that we can get peripheral which returns the PERMAP field of the transfer information.
    func testGetPeripheral() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.transferInformation = DMATransferInformation(rawValue: 5 << 16)
        
        XCTAssertEqual(controlBlock.peripheral, .pwm)
    }
    
    /// Test that we can set peripheral, which sets the PERMAP field of the transfer information.
    func testSetPeripheral() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.peripheral = .sdHost
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 16) & ~(~0 << 5), 13)
    }
    
    /// Test that when we set peripheral, any existing bits are cleared.
    func testSetPeripheralIdempotent() {
        var controlBlock = DMAControlBlock()
        
        // Corrupt the field to ensure the bits are set.
        controlBlock.transferInformation = DMATransferInformation(rawValue: ~0)
        
        controlBlock.peripheral = .hdmi
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 16) & ~(~0 << 5), 17)
    }
    
    /// Test that when we set peripheral, other fields are not altered.
    func testSetPeripheralDiscrete() {
        var controlBlock = DMAControlBlock()
        
        // Corrupt the field to ensure the bits are set.
        controlBlock.transferInformation = DMATransferInformation(rawValue: ~0)
        
        controlBlock.peripheral = .eMMC
        
        XCTAssertEqual(controlBlock.transferInformation.rawValue | (~(~0 << 5) << 16), ~0)
    }

    
    // MARK: burstTransferLength
    
    /// Test that we can get burstTransferLength which returns the BURST_LENGTH field of the transfer information.
    func testGetBurstTransferLength() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.transferInformation = DMATransferInformation(rawValue: 7 << 12)
        
        XCTAssertEqual(controlBlock.burstTransferLength, 7)
    }
    
    /// Test that we can set burstTransferLength, which sets the BURST_LENGTH field of the transfer information.
    func testSetBurstTransferLength() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.burstTransferLength = 9
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 12) & ~(~0 << 4), 9)
    }
    
    /// Test that when we set burstTransferLength, any existing bits are cleared.
    func testSetBurstTransferLengthIdempotent() {
        var controlBlock = DMAControlBlock()
        
        // Corrupt the field to ensure the bits are set.
        controlBlock.transferInformation = DMATransferInformation(rawValue: ~0)
        
        controlBlock.burstTransferLength = 8
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 12) & ~(~0 << 4), 8)
    }
    
    /// Test that when we set burstTransferLength, other fields are not altered.
    func testSetBurstTransferLengthDiscrete() {
        var controlBlock = DMAControlBlock()
        
        // Corrupt the field to ensure the bits are set.
        controlBlock.transferInformation = DMATransferInformation(rawValue: ~0)
        
        controlBlock.burstTransferLength = 8
        
        XCTAssertEqual(controlBlock.transferInformation.rawValue | (~(~0 << 4) << 12), ~0)
    }

    
    // MARK: waitForWriteResponse
    
    /// Test that we can set waitForWriteResponse, which sets the WAIT_RESP bit of the transfer information.
    func testSetWaitForWriteResponse() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.waitForWriteResponse = true
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 3) & 1, 1)
    }
    
    /// Test that we can clear waitForWriteResponse, which removes the WAIT_RESP bit from the transfer information.
    func testClearWaitForWriteResponse() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: ~0)
        
        controlBlock.waitForWriteResponse = false
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 3) & 1, 0)
    }
    
    /// Test that waitForWriteResponse is true when the WAIT_RESP bit of the transfer information is set.
    func testGetWaitForWriteResponse() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: 1 << 3)
        
        XCTAssertEqual(controlBlock.waitForWriteResponse, true)
    }
    
    /// Test that waitForWriteResponse defaults to false when the WAIT_RESP bit of the transfer information is not set.
    func testDefaultWaitForWriteResponse() {
        let controlBlock = DMAControlBlock()
        
        XCTAssertEqual(controlBlock.waitForWriteResponse, false)
    }

    
    // MARK: is2D

    /// Test that we can set 2D Mode, which sets the TDMODE bit of the transfer information.
    func testSetIs2DMode() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.is2D = true
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 1) & 1, 1)
    }
    
    /// Test that we can clear 2D Mode, which removes the TDMODE bit from the transfer information.
    func testClearIs2DMode() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: ~0)
        
        controlBlock.is2D = false
        
        XCTAssertEqual((controlBlock.transferInformation.rawValue >> 1) & 1, 0)
    }

    /// Test that is2D is true when the TDMODE bit of the transfer information is set.
    func testGetIs2DMode() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: 1 << 1)

        XCTAssertEqual(controlBlock.is2D, true)
    }

    /// Test that is2D defaults to false when the TDMODE bit of the transfer information is not set.
    func testDefaultIs2DMode() {
        let controlBlock = DMAControlBlock()

        XCTAssertEqual(controlBlock.is2D, false)
    }
    
    
    // MARK: raiseInterrupt
    
    /// Test that we can enable interrupts, which sets the INTEN bit of the transfer information.
    func testSetRaiseInterrupt() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.raiseInterrupt = true
        
        XCTAssertEqual(controlBlock.transferInformation.rawValue & 1, 1)
    }
    
    /// Test that we can clear enable interrupts, which removes the INTEN bit from the transfer information.
    func testClearRaiseInterrupt() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: ~0)
        
        controlBlock.raiseInterrupt = false
        
        XCTAssertEqual(controlBlock.transferInformation.rawValue & 1, 0)
    }
    
    /// Test that raiseInterrupt is true when the INTEN bit of the transfer information is set.
    func testGetRaiseInterrupt() {
        var controlBlock = DMAControlBlock()
        controlBlock.transferInformation = DMATransferInformation(rawValue: 1)
        
        XCTAssertEqual(controlBlock.raiseInterrupt, true)
    }
    
    /// Test that raiseInterrupt defaults to false when the INTEN bit of the transfer information is not set.
    func testDefaultRaiseInterrupt() {
        let controlBlock = DMAControlBlock()
        
        XCTAssertEqual(controlBlock.raiseInterrupt, false)
    }

    
    // MARK: yLength
    
    /// Test that we can get the Y Length field from the transfer length.
    func testGetYLength() {
        var controlBlock = DMAControlBlock()

        controlBlock.transferLength = (22 << 16) | 15
        
        XCTAssertEqual(controlBlock.yLength, 22)
    }

    /// Test that we can set the Y Length field from the transfer length.
    func testSetYLength() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.yLength = 19
        
        XCTAssertEqual(controlBlock.transferLength >> 16 & ~(~0 << 14), 19)
    }

    /// Test that when we the Y Length field of the transfer length, previous bits are cleared.
    func testSetYLengthIdempotent() {
        var controlBlock = DMAControlBlock()
        
        // Corrupt the field to ensure bits are cleared.
        controlBlock.transferLength = ~0
        
        controlBlock.yLength = 42
        
        XCTAssertEqual(controlBlock.transferLength >> 16 & ~(~0 << 14), 42)
    }

    /// Test that when we the Y Length field of the transfer length, other bits are left alone.
    func testSetYLengthDiscrete() {
        var controlBlock = DMAControlBlock()
        
        // Corrupt the field to ensure bits are cleared.
        controlBlock.transferLength = ~0
        
        controlBlock.yLength = 37
        
        XCTAssertEqual(controlBlock.transferLength | (~(~0 << 14) << 16), ~0)
    }

    
    // MARK: xLength
    
    /// Test that we can get the X Length field from the transfer length.
    func testGetXLength() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.transferLength = (22 << 16) | 15
        
        XCTAssertEqual(controlBlock.xLength, 15)
    }

    /// Test that we can set the X Length field from the transfer length.
    func testSetXLength() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.xLength = 7
        
        XCTAssertEqual(controlBlock.transferLength & ~(~0 << 16), 7)
    }
    
    /// Test that when we the X Length field of the transfer length, previous bits are cleared.
    func testSetXLengthIdempotent() {
        var controlBlock = DMAControlBlock()
        
        // Corrupt the field to ensure bits are cleared.
        controlBlock.transferLength = ~0
        
        controlBlock.xLength = 66
        
        XCTAssertEqual(controlBlock.transferLength & ~(~0 << 16), 66)
    }
    
    /// Test that when we the X Length field of the transfer length, other bits are left alone.
    func testSetXLengthDiscrete() {
        var controlBlock = DMAControlBlock()
        
        // Corrupt the field to ensure bits are cleared.
        controlBlock.transferLength = ~0
        
        controlBlock.xLength = 4
        
        XCTAssertEqual(controlBlock.transferLength | ~(~0 << 16), ~0)
    }

    
    // MARK: sourceStride

    /// Test that we can get a positive source stride field from the stride.
    func testGetPositiveSourceStride() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.stride = (16_384 << 16) | (8_192)
        
        XCTAssertEqual(controlBlock.sourceStride, 8_192)
    }
    
    /// Test that we can get a negative source stride field from the stride.
    func testGetNegativeSourceStride() {
        var controlBlock = DMAControlBlock()
        
        // 2's complement means -8192 is stored as ~(8192 -1)
        controlBlock.stride = (16_384 << 16) | (~(8_192 - 1) & ~(~0 << 16))
        
        XCTAssertEqual(controlBlock.sourceStride, -8_192)
    }
    
    /// Test that we can set a positive source stride field into the stride.
    func testSetPositiveSourceStride() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.sourceStride = 4_096
        
        XCTAssertEqual(controlBlock.stride & ~(~0 << 16), 4_096)
    }

    /// Test that we can set a negative source stride field into the stride.
    func testSetNegativeSourceStride() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.sourceStride = -4_096
        
        // 2's complement means -4096 is stored as ~(4096 - 1)
        let expected: UInt32 = ~(4_096 - 1) & ~(~0 << 16)
        XCTAssertEqual(controlBlock.stride & ~(~0 << 16), expected)
    }

    /// Test that when we set a positive source stride, previous bits are cleared.
    func testSetPositiveSourceStrideIdempotent() {
        var controlBlock = DMAControlBlock()
        
        // Corrupt the bits to ensure they change to zero.
        controlBlock.stride = ~0
        
        controlBlock.sourceStride = 20_480
        
        XCTAssertEqual(controlBlock.stride & ~(~0 << 16), 20_480)
    }

    /// Test that when we set a negative source stride, previous bits are cleared.
    func testSetNegativeSourceStrideIdempotent() {
        var controlBlock = DMAControlBlock()
        
        // Corrupt the bits to ensure they change to zero.
        controlBlock.stride = ~0
        
        controlBlock.sourceStride = -28672
        
        // 2's complement means -28672 is stored as ~(28672 - 1)
        let expected: UInt32 = ~(28_672 - 1) & ~(~0 << 16)
        XCTAssertEqual(controlBlock.stride & ~(~0 << 16), expected)
    }

    /// Test that when we set a positive source stride, the destination stride field is not changed.
    func testSetPositiveSourceStrideDiscrete() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.stride = (16_384 << 16) | (8_192)

        controlBlock.sourceStride = 512
        
        XCTAssertEqual((controlBlock.stride >> 16) & ~(~0 << 16), 16_384)
    }
    
    /// Test that when we set a negative source stride, the destination stride field is not changed.
    func testSetNegativeSourceStrideDiscrete() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.stride = (16_384 << 16) | (8_192)

        controlBlock.sourceStride = -384

        XCTAssertEqual((controlBlock.stride >> 16) & ~(~0 << 16), 16_384)
    }

    
    // MARK: destinationStride
    
    /// Test that we can get a positive destination stride field from the stride.
    func testGetPositiveDestinationStride() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.stride = (16_384 << 16) | (8_192)
        
        XCTAssertEqual(controlBlock.destinationStride, 16_384)
    }
    
    /// Test that we can get a negative destination stride field from the stride.
    func testGetNegativeDestinationStride() {
        var controlBlock = DMAControlBlock()
        
        // 2's complement means -16284 is stored as ~(16384 - 1)
        controlBlock.stride = ((~(16_384 - 1) & ~(~0 << 16)) << 16) | 8_192
        
        XCTAssertEqual(controlBlock.destinationStride, -16_384)
    }
    
    /// Test that we can set a positive destination stride field into the stride.
    func testSetPositiveDestinationStride() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.destinationStride = 4_096
        
        XCTAssertEqual((controlBlock.stride >> 16) & ~(~0 << 16), 4_096)
    }
    
    /// Test that we can set a negative destination stride field into the stride.
    func testSetNegativeDestinationStride() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.destinationStride = -4_096
        
        // 2's complement means -4096 is stored as ~(4096 - 1)
        let expected: UInt32 = ~(4_096 - 1) & ~(~0 << 16)
        XCTAssertEqual((controlBlock.stride >> 16) & ~(~0 << 16), expected)
    }
    
    /// Test that when we set a positive destination stride, previous bits are cleared.
    func testSetPositiveDestinationStrideIdempotent() {
        var controlBlock = DMAControlBlock()
        
        // Corrupt the bits to ensure they change to zero.
        controlBlock.stride = ~0
        
        controlBlock.destinationStride = 20_480
        
        XCTAssertEqual((controlBlock.stride >> 16) & ~(~0 << 16), 20_480)
    }
    
    /// Test that when we set a negative destination stride, previous bits are cleared.
    func testSetNegativeDestinationStrideIdempotent() {
        var controlBlock = DMAControlBlock()
        
        // Corrupt the bits to ensure they change to zero.
        controlBlock.stride = ~0
        
        controlBlock.destinationStride = -28672
        
        // 2's complement means -28672 is stored as ~(28672 - 1)
        let expected: UInt32 = ~(28_672 - 1) & ~(~0 << 16)
        XCTAssertEqual((controlBlock.stride >> 16) & ~(~0 << 16), expected)
    }
    
    /// Test that when we set a positive destination stride, the destination stride field is not changed.
    func testSetPositiveDestinationStrideDiscrete() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.stride = (16_384 << 16) | (8_192)
        
        controlBlock.destinationStride = 512
        
        XCTAssertEqual(controlBlock.stride & ~(~0 << 16), 8_192)
    }
    
    /// Test that when we set a negative destination stride, the destination stride field is not changed.
    func testSetNegativeDestinationStrideDiscrete() {
        var controlBlock = DMAControlBlock()
        
        controlBlock.stride = (16_384 << 16) | (8_192)
        
        controlBlock.destinationStride = -384
        
        XCTAssertEqual(controlBlock.stride & ~(~0 << 16), 8_192)
    }

}
