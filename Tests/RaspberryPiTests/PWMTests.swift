//
//  PWMTests.swift
//  RaspberryPiTests
//
//  Created by Scott James Remnant on 6/7/18.
//

import XCTest

@testable import RaspberryPi

class PWMLayoutTests : XCTestCase {

    // MARK: Layout

    /// Test that the layout of the Registers struct matches hardware.
    func testRegistersLayout() {
        XCTAssertEqual(MemoryLayout<PWM.Registers>.size, 0x28)
        XCTAssertEqual(MemoryLayout<PWMControl>.size, 0x04)
        XCTAssertEqual(MemoryLayout<PWMStatus>.size, 0x04)
        XCTAssertEqual(MemoryLayout<PWMDMAConfiguration>.size, 0x04)

        #if swift(>=4.1.5)
        XCTAssertEqual(MemoryLayout.offset(of: \PWM.Registers.control), 0x00)
        XCTAssertEqual(MemoryLayout.offset(of: \PWM.Registers.status), 0x04)
        XCTAssertEqual(MemoryLayout.offset(of: \PWM.Registers.dmaConfiguration), 0x08)
        XCTAssertEqual(MemoryLayout.offset(of: \PWM.Registers.channel1Range), 0x10)
        XCTAssertEqual(MemoryLayout.offset(of: \PWM.Registers.channel1Data), 0x14)
        XCTAssertEqual(MemoryLayout.offset(of: \PWM.Registers.fifoInput), 0x18)
        XCTAssertEqual(MemoryLayout.offset(of: \PWM.Registers.channel2Range), 0x20)
        XCTAssertEqual(MemoryLayout.offset(of: \PWM.Registers.channel2Data), 0x24)
        #endif
    }

}

class PWMTests : XCTestCase {

    var registers = PWM.Registers()
    var pwm: PWM!
    
    override func setUp() {
        registers = PWM.Registers()
        pwm = PWM(registers: &registers)
    }
    
    override func tearDown() {
        pwm = nil
    }


    // MARK: Collection conformance

    /// Test that the collection implementation produces a correct count.
    func testCount() {
        XCTAssertEqual(pwm.count, 2)
    }

    /// Test that the start index of the collection is one.
    func testStartIndex() {
        XCTAssertEqual(pwm.startIndex, 1)
    }

    /// Test that the end index of the collection is the count plus one.
    func testEndIndex() {
        XCTAssertEqual(pwm.endIndex, 3)
    }

    /// Test that the collection implementation has correct indexes.
    func testIndexes() {
        XCTAssertEqual(Array(pwm.indices), Array(1...2))
    }


    // MARK: isEnabled

    /// Test that enabling channel 1 sets the appopriate bit.
    func testSetOneIsEnabled() {
        pwm[1].isEnabled = true

        XCTAssertEqual(registers.control.rawValue & 1, 1)
    }

    /// Test that disabling channel 1 clears the appropriate bit.
    func testClearOneIsEnabled() {
        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm[1].isEnabled = false

        XCTAssertEqual(registers.control.rawValue & 1, 0)
    }

    /// Test that isEnabled is true for channel 1 when the appropriate bit is set.
    func testGetOneIsEnabled() {
        registers.control = PWMControl(rawValue: 1)

        XCTAssertEqual(pwm[1].isEnabled, true)
    }

    /// Test that isEnabled is false for channel 1 when the appropriate bit is not set.
    func testDefaultOneIsEnabled() {
        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm[1].isEnabled, false)
    }

    /// Test that enabling channel 2 sets the appopriate bit.
    func testSetTwoIsEnabled() {
        pwm[2].isEnabled = true

        XCTAssertEqual((registers.control.rawValue >> 8) & 1, 1)
    }

    /// Test that disabling channel 2 clears the appropriate bit.
    func testClearTwoIsEnabled() {
        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm[2].isEnabled = false

        XCTAssertEqual((registers.control.rawValue >> 8) & 1, 0)
    }

    /// Test that isEnabled is true for channel 2 when the appropriate bit is set.
    func testGetTwoIsEnabled() {
        registers.control = PWMControl(rawValue: 1 << 8)

        XCTAssertEqual(pwm[2].isEnabled, true)
    }

    /// Test that isEnabled is false for channel 2 when the appropriate bit is not set.
    func testDefaultTwoIsEnabled() {
        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm[2].isEnabled, false)
    }


    // MARK: mode

    /// Test that we can set the mode of channel 1 to PWM. MODE1 and MSEN1 should be both 0.
    func testSetOneModePWM() {
        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm[1].mode = .pwm

        XCTAssertEqual((registers.control.rawValue >> 1) & 1, 0)
        XCTAssertEqual((registers.control.rawValue >> 7) & 1, 0)
    }

    /// Test that we can set the mode of channel 1 to Mark-space. MODE1 should be 0 and MSEN1 should be 1.
    func testSetOneModeMarkSpace() {
        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0 ^ (1 << 7))

        pwm[1].mode = .markSpace

        XCTAssertEqual((registers.control.rawValue >> 1) & 1, 0)
        XCTAssertEqual((registers.control.rawValue >> 7) & 1, 1)
    }

    /// Test that we can set the mode of channel 1 to Serializer. MODE1 should be 1 and MSEN1 should be 0.
    func testSetOneModeSerializer() {
        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0 ^ (1 << 1))

        pwm[1].mode = .serializer

        XCTAssertEqual((registers.control.rawValue >> 1) & 1, 1)
        XCTAssertEqual((registers.control.rawValue >> 7) & 1, 0)
    }

    /// Test that when MODE1 and MSEN1 are both 0, the returned mode is PWM.
    func testGetOneModePWM() {
        XCTAssertEqual(pwm[1].mode, .pwm)
    }

    /// Test that when MODE1 is 0 and MSEN1 is 1, the returned mode is Mark-space.
    func testGetOneModeMarkSpace() {
        registers.control = PWMControl(rawValue: 1 << 7)

        XCTAssertEqual(pwm[1].mode, .markSpace)
    }

    /// Test that when MODE1 is 1 and MSEN1 is 0, the returned mode is Serializer.
    func testGetOneModeSerializer() {
        registers.control = PWMControl(rawValue: 1 << 1)

        XCTAssertEqual(pwm[1].mode, .serializer)
    }

    /// Test that when MODE1 and MSEN1 are both 1, the returned mode is still Serializer.
    func testGetOneModeSerializerInvalid() {
        registers.control = PWMControl(rawValue: (1 << 7) | (1 << 1))

        XCTAssertEqual(pwm[1].mode, .serializer)
    }

    /// Test that we can set the mode of channel 2 to PWM. MODE2 and MSEN2 should be both 0.
    func testSetTwoModePWM() {
        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm[2].mode = .pwm

        XCTAssertEqual((registers.control.rawValue >> 9) & 1, 0)
        XCTAssertEqual((registers.control.rawValue >> 15) & 1, 0)
    }

    /// Test that we can set the mode of channel 2 to Mark-space. MODE2 should be 0 and MSEN2 should be 1.
    func testSetTwoModeMarkSpace() {
        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0 ^ (1 << 15))

        pwm[2].mode = .markSpace

        XCTAssertEqual((registers.control.rawValue >> 9) & 1, 0)
        XCTAssertEqual((registers.control.rawValue >> 15) & 1, 1)
    }

    /// Test that we can set the mode of channel 2 to Serializer. MODE2 should be 1 and MSEN2 should be 0.
    func testSetTwoModeSerializer() {
        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0 ^ (1 << 9))

        pwm[2].mode = .serializer

        XCTAssertEqual((registers.control.rawValue >> 9) & 1, 1)
        XCTAssertEqual((registers.control.rawValue >> 15) & 1, 0)
    }

    /// Test that when MODE2 and MSEN2 are both 0, the returned mode is PWM.
    func testGetTwoModePWM() {
        XCTAssertEqual(pwm[2].mode, .pwm)
    }

    /// Test that when MODE2 is 0 and MSEN2 is 1, the returned mode is Mark-space.
    func testGetTwoModeMarkSpace() {
        registers.control = PWMControl(rawValue: 1 << 15)

        XCTAssertEqual(pwm[2].mode, .markSpace)
    }

    /// Test that when MODE2 is 1 and MSEN2 is 0, the returned mode is Serializer.
    func testGetTwoModeSerializer() {
        registers.control = PWMControl(rawValue: 1 << 9)

        XCTAssertEqual(pwm[2].mode, .serializer)
    }

    /// Test that when MODE2 and MSEN2 are both 1, the returned mode is still Serializer.
    func testGetTwoModeSerializerInvalid() {
        registers.control = PWMControl(rawValue: (1 << 15) | (1 << 9))

        XCTAssertEqual(pwm[2].mode, .serializer)
    }


    // MARK: range

    /// Test that we can set the range of channel 1.
    func testSetRangeOne() {
        pwm[1].range = 50

        XCTAssertEqual(registers.channel1Range, 50)
    }

    /// Test that we can set the range of channel 2.
    func testSetRangeTwo() {
        pwm[2].range = 97

        XCTAssertEqual(registers.channel2Range, 97)
    }

    /// Test that we can get the range of channel 1.
    func testGetRangeOne() {
        registers.channel1Range = 87

        XCTAssertEqual(pwm[1].range, 87)
    }

    /// Test that we can get the range of channel 2.
    func testGetRangeTwo() {
        registers.channel2Range = 93

        XCTAssertEqual(pwm[2].range, 93)
    }


    // MARK: data

    /// Test that we can set the range of channel 1.
    func testSetDataOne() {
        pwm[1].data = 50

        XCTAssertEqual(registers.channel1Data, 50)
    }

    /// Test that we can set the range of channel 2.
    func testSetDataTwo() {
        pwm[2].data = 97

        XCTAssertEqual(registers.channel2Data, 97)
    }

    /// Test that we can get the range of channel 1.
    func testGetDataOne() {
        registers.channel1Data = 87

        XCTAssertEqual(pwm[1].data, 87)
    }

    /// Test that we can get the range of channel 2.
    func testGetDataTwo() {
        registers.channel2Data = 93

        XCTAssertEqual(pwm[2].data, 93)
    }


    // MARK: silenceBit

    /// Test that setting the silence bit of channel 1 to high sets the appopriate bit.
    func testSetOneSilenceBitHigh() {
        pwm[1].silenceBit = .high

        XCTAssertEqual((registers.control.rawValue >> 3) & 1, 1)
    }

    /// Test that setting the silence bit of channel 1 to low clears the appropriate bit.
    func testSetOneSilenceBitLow() {
        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm[1].silenceBit = .low

        XCTAssertEqual((registers.control.rawValue >> 3) & 1, 0)
    }

    /// Test that silenceBit is .high for channel 1 when the appropriate bit is set.
    func testGetOneSilenceBit() {
        registers.control = PWMControl(rawValue: 1 << 3)

        XCTAssertEqual(pwm[1].silenceBit, .high)
    }

    /// Test that silenceBit is .low for channel 1 when the appropriate bit is not set.
    func testDefaultOneSilenceBit() {
        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm[1].silenceBit, .low)
    }

    /// Test that setting the silence bit of channel 2 to high sets the appopriate bit.
    func testSetTwoSilenceBit() {
        pwm[2].silenceBit = .high

        XCTAssertEqual((registers.control.rawValue >> 11) & 1, 1)
    }

    /// Test that setting the silence bit of channel 2 to low clears the appropriate bit.
    func testClearTwoSilenceBit() {
        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm[2].silenceBit = .low

        XCTAssertEqual((registers.control.rawValue >> 11) & 1, 0)
    }

    /// Test that silenceBit is .high for channel 2 when the appropriate bit is set.
    func testGetTwoSilenceBit() {
        registers.control = PWMControl(rawValue: 1 << 11)

        XCTAssertEqual(pwm[2].silenceBit, .high)
    }

    /// Test that silenceBit is .low for channel 2 when the appropriate bit is not set.
    func testDefaultTwoSilenceBit() {
        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm[2].silenceBit, .low)
    }


    // MARK: invertPolarity

    /// Test that inverting polarity of channel 1 sets the appopriate bit.
    func testSetOneInvertPolarity() {
        pwm[1].invertPolarity = true

        XCTAssertEqual((registers.control.rawValue >> 4) & 1, 1)
    }

    /// Test that using normal polarity for channel 1 clears the appropriate bit.
    func testClearOneInvertPolarity() {
        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm[1].invertPolarity = false

        XCTAssertEqual((registers.control.rawValue >> 4) & 1, 0)
    }

    /// Test that invertPolarity is true for channel 1 when the appropriate bit is set.
    func testGetOneInvertPolarity() {
        registers.control = PWMControl(rawValue: 1 << 4)

        XCTAssertEqual(pwm[1].invertPolarity, true)
    }

    /// Test that invertPolarity is false for channel 1 when the appropriate bit is not set.
    func testDefaultOneInvertPolarity() {
        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm[1].invertPolarity, false)
    }

    /// Test that inverting polarity of channel 2 sets the appopriate bit.
    func testSetTwoInvertPolarity() {
        pwm[2].invertPolarity = true

        XCTAssertEqual((registers.control.rawValue >> 12) & 1, 1)
    }

    /// Test that using normal polarity for channel 2 clears the appropriate bit.
    func testClearTwoInvertPolarity() {
        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm[2].invertPolarity = false

        XCTAssertEqual((registers.control.rawValue >> 12) & 1, 0)
    }

    /// Test that invertPolarity is true for channel 2 when the appropriate bit is set.
    func testGetTwoInvertPolarity() {
        registers.control = PWMControl(rawValue: 1 << 12)

        XCTAssertEqual(pwm[2].invertPolarity, true)
    }

    /// Test that invertPolarity is false for channel 2 when the appropriate bit is not set.
    func testDefaultTwoInvertPolarity() {
        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm[2].invertPolarity, false)
    }


    // MARK: channel status

    /// Test that the channel 1 state status bit is returned via isTransmitting.
    func testOneIsTransmitting() {
        registers.status = PWMStatus(rawValue: 1 << 9)

        XCTAssertEqual(pwm[1].isTransmitting, true)
    }

    /// Test that the channel 2 state status bit is returned via isTransmitting.
    func testTwoIsTransmitting() {
        registers.status = PWMStatus(rawValue: 1 << 10)

        XCTAssertEqual(pwm[2].isTransmitting, true)
    }

    /// Test that the default of channel 1 isTransmitting is false.
    func testDefaultOneIsTransmitting() {
        XCTAssertEqual(pwm[1].isTransmitting, false)
    }

    /// Test that the default of channel 2 isTransmitting is false.
    func testDefaultTwoIsTransmitting() {
        XCTAssertEqual(pwm[2].isTransmitting, false)
    }

    /// Test that the channel 1 gap occurred status bit is returned via gapOccurred.
    func testOneGapOccurred() {
        registers.status = PWMStatus(rawValue: 1 << 4)

        XCTAssertEqual(pwm[1].gapOccurred, true)
    }

    /// Test that the channel 2 gap occurred status bit is returned via gapOccurred.
    func testTwoGapOccurred() {
        registers.status = PWMStatus(rawValue: 1 << 5)

        XCTAssertEqual(pwm[2].gapOccurred, true)
    }

    /// Test that the default channel 1 gapOccurred is false.
    func testDefaultOneGapOccurred() {
        XCTAssertEqual(pwm[1].gapOccurred, false)
    }

    /// Test that the default channel 2 gapOccurred is false.
    func testDefaultTwoGapOccurred() {
        XCTAssertEqual(pwm[2].gapOccurred, false)
    }

    /// Test the the channel 1 gap occurred status bit is written when clearing.
    func testClearOneGapOccurred() {
        pwm[1].gapOccurred = false

        XCTAssertEqual((registers.status.rawValue >> 4) & 1, 1)
    }

    /// Test the the channel 2 gap occurred status bit is written when clearing.
    func testClearTwoGapOccurred() {
        pwm[2].gapOccurred = false

        XCTAssertEqual((registers.status.rawValue >> 5) & 1, 1)
    }

    /// Test that writing true to channel 1 gapOccurred has no effect.
    func testOneGapOccurredNoop() {
        pwm[1].gapOccurred = true

        XCTAssertEqual(registers.status.rawValue, 0)
    }

    /// Test that writing true to channel 2 gapOccurred has no effect.
    func testTwoGapOccurredNoop() {
        pwm[2].gapOccurred = true

        XCTAssertEqual(registers.status.rawValue, 0)
    }


    // MARK: bus error

    /// Test that the bus error status bit is returned via isBusError.
    func testIsBusError() {
        registers.status = PWMStatus(rawValue: 1 << 8)

        XCTAssertEqual(pwm.isBusError, true)
    }

    /// Test isBusError defaults to false.
    func testDefaultIsBusError() {
        XCTAssertEqual(pwm.isBusError, false)
    }

    /// Test that the bus error is cleared by writing false to isBusError.
    func testClearIsBusError() {
        pwm.isBusError = false

        XCTAssertEqual((registers.status.rawValue >> 8) & 1, 1)
    }

    /// Test that writing true to isBusError is a no-op.
    func testIsBusErrorNoop() {
        pwm.isBusError = true

        XCTAssertEqual(registers.status.rawValue, 0)
    }


    // MARK: useFifo

    /// Test that using the fifo for channel 1 sets the appopriate bit.
    func testSetOneUseFifo() {
        pwm[1].useFifo = true

        XCTAssertEqual((registers.control.rawValue >> 5) & 1, 1)
    }

    /// Test that using data for channel 1 clears the appropriate bit.
    func testClearOneUseFifo() {
        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm[1].useFifo = false

        XCTAssertEqual((registers.control.rawValue >> 5) & 1, 0)
    }

    /// Test that useFifo is true for channel 1 when the appropriate bit is set.
    func testGetOneUseFifo() {
        registers.control = PWMControl(rawValue: 1 << 5)

        XCTAssertEqual(pwm[1].useFifo, true)
    }

    /// Test that useFifo is false for channel 1 when the appropriate bit is not set.
    func testDefaultOneUseFifo() {
        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm[1].useFifo, false)
    }

    /// Test that using the fifo for channel 2 sets the appopriate bit.
    func testSetTwoUseFifo() {
        pwm[2].useFifo = true

        XCTAssertEqual((registers.control.rawValue >> 13) & 1, 1)
    }

    /// Test that using data for channel 2 clears the appropriate bit.
    func testClearTwoUseFifo() {
        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm[2].useFifo = false

        XCTAssertEqual((registers.control.rawValue >> 13) & 1, 0)
    }

    /// Test that useFifo is true for channel 2 when the appropriate bit is set.
    func testGetTwoUseFifo() {
        registers.control = PWMControl(rawValue: 1 << 13)

        XCTAssertEqual(pwm[2].useFifo, true)
    }

    /// Test that useFifo is false for channel 2 when the appropriate bit is not set.
    func testDefaultTwoUseFifo() {
        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm[2].useFifo, false)
    }


    // MARK: addToFifo

    /// Test that we can write to the FiFo.
    func testAddToFifo() {
        pwm.addToFifo(99)

        XCTAssertEqual(registers.fifoInput, 99)
    }


    // MARK: clearFifo

    /// Test that calling the method sets the appropriate bit in the control register.
    func testClearFifo() {
        pwm.clearFifo()

        XCTAssertEqual((registers.control.rawValue >> 6) & 1, 1)
    }


    // MARK: repeatLastData

    /// Test that repeating fifo data for channel 1 sets the appopriate bit.
    func testSetOneRepeatLastData() {
        pwm[1].repeatLastData = true

        XCTAssertEqual((registers.control.rawValue >> 2) & 1, 1)
    }

    /// Test that silence for channel 1 clears the appropriate bit.
    func testClearOneRepeatLastData() {
        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm[1].repeatLastData = false

        XCTAssertEqual((registers.control.rawValue >> 2) & 1, 0)
    }

    /// Test that repeatLastData is true for channel 1 when the appropriate bit is set.
    func testGetOneRepeatLastData() {
        registers.control = PWMControl(rawValue: 1 << 2)

        XCTAssertEqual(pwm[1].repeatLastData, true)
    }

    /// Test that repeatLastData is false for channel 1 when the appropriate bit is not set.
    func testDefaultOneRepeatLastData() {
        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm[1].repeatLastData, false)
    }

    /// Test that repeating fifo data for channel 2 sets the appopriate bit.
    func testSetTwoRepeatLastData() {
        pwm[2].repeatLastData = true

        XCTAssertEqual((registers.control.rawValue >> 10) & 1, 1)
    }

    /// Test that silence for channel 2 clears the appropriate bit.
    func testClearTwoRepeatLastData() {
        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm[2].repeatLastData = false

        XCTAssertEqual((registers.control.rawValue >> 10) & 1, 0)
    }

    /// Test that repeatLastData is true for channel 2 when the appropriate bit is set.
    func testGetTwoRepeatLastData() {
        registers.control = PWMControl(rawValue: 1 << 10)

        XCTAssertEqual(pwm[2].repeatLastData, true)
    }

    /// Test that repeatLastData is false for channel 2 when the appropriate bit is not set.
    func testDefaultTwoRepeatLastData() {
        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm[2].repeatLastData, false)
    }


    // MARK: FIFO status

    /// Test that the fifo empty status bit is returned via isFifoEmpty.
    func testIsFifoEmpty() {
        registers.status = PWMStatus(rawValue: 1 << 1)

        XCTAssertEqual(pwm.isFifoEmpty, true)
    }

    /// Test isFifoEmpty defaults to false.
    func testDefaultIsFifoEmpty() {
        XCTAssertEqual(pwm.isFifoEmpty, false)
    }

    /// Test that the fifo read error status bit is returned via isFifoReadError.
    func testIsFifoReadError() {
        registers.status = PWMStatus(rawValue: 1 << 3)

        XCTAssertEqual(pwm.isFifoReadError, true)
    }

    /// Test isFifoReadError defaults to false.
    func testDefaultIsFifoReadError() {
        XCTAssertEqual(pwm.isFifoReadError, false)
    }

    /// Test that the fifo read error is cleared by writing false to isFifoReadError.
    func testClearIsFifoReadError() {
        pwm.isFifoReadError = false

        XCTAssertEqual((registers.status.rawValue >> 3) & 1, 1)
    }

    /// Test that writing true to isFifoReadError is a no-op.
    func testIsFifoReadErrorNoop() {
        pwm.isFifoReadError = true

        XCTAssertEqual(registers.status.rawValue, 0)
    }

    /// Test that the fifo empty status bit is returned via isFifoFull.
    func testIsFifoFull() {
        registers.status = PWMStatus(rawValue: 1)

        XCTAssertEqual(pwm.isFifoFull, true)
    }

    /// Test isFifoFull defaults to false.
    func testDefaultIsFifoFull() {
        XCTAssertEqual(pwm.isFifoFull, false)
    }

    /// Test that the fifo write error status bit is returned via isFifoWriteError.
    func testIsFifoWriteError() {
        registers.status = PWMStatus(rawValue: 1 << 2)

        XCTAssertEqual(pwm.isFifoWriteError, true)
    }

    /// Test isFifoWriteError defaults to false.
    func testDefaultIsFifoWriteError() {
        XCTAssertEqual(pwm.isFifoWriteError, false)
    }

    /// Test that the fifo write error is cleared by writing false to isFifoWriteError.
    func testClearIsFifoWriteError() {
        pwm.isFifoWriteError = false

        XCTAssertEqual((registers.status.rawValue >> 2) & 1, 1)
    }

    /// Test that writing true to isFifoWriteError is a no-op.
    func testIsFifoWriteErrorNoop() {
        pwm.isFifoWriteError = true

        XCTAssertEqual(registers.status.rawValue, 0)
    }


    // MARK: DMA Configuration

    /// Test that enabling DMA sets the appopriate bit.
    func testSetIsDMAEnabled() {
        pwm.isDMAEnabled = true

        XCTAssertEqual((registers.dmaConfiguration.rawValue >> 31) & 1, 1)
    }

    /// Test that enabling DMA doesn't corrupt the thresholds.
    func testSetIsDMAEnabledIdempotent() {
        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: (3 << 8) | 5)
        pwm.isDMAEnabled = true

        XCTAssertEqual(pwm.panicThreshold, 3)
        XCTAssertEqual(pwm.dataRequestThreshold, 5)
    }

    /// Test that disabling DMA clears the appropriate bit.
    func testClearIsDMAEnabled() {
        // Corrupt the register to ensure bits are cleared.
        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: ~0)

        pwm.isDMAEnabled = false

        XCTAssertEqual((registers.dmaConfiguration.rawValue >> 31) & 1, 0)
    }

    /// Test that disabling DMA doesn't corrupt the thresholds.
    func testClearIsDMAEnabledIdempotent() {
        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: (1 << 31) | (3 << 8) | 5)
        pwm.isDMAEnabled = false

        XCTAssertEqual(pwm.panicThreshold, 3)
        XCTAssertEqual(pwm.dataRequestThreshold, 5)
    }

    /// Test that isDMAEnabled is true when the appropriate bit is set.
    func testGetIsDMAEnabled() {
        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: 1 << 31)

        XCTAssertEqual(pwm.isDMAEnabled, true)
    }

    /// Test that isDMAEnabled is false when the appropriate bit is not set.
    func testDefaultIsDMAEnabled() {
        XCTAssertEqual(pwm.isDMAEnabled, false)
    }

    /// Test that we can set the panic threshold.
    func testSetPanicThreshold() {
        pwm.panicThreshold = 5

        XCTAssertEqual((registers.dmaConfiguration.rawValue >> 8) & ~(~0 << 8), 5)
    }

    /// Test that when we set the panic threshold, it clears existing bits in the register.
    func testSetPanicThresholdClears() {
        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: ~0)

        pwm.panicThreshold = 5

        XCTAssertEqual((registers.dmaConfiguration.rawValue >> 8) & ~(~0 << 8), 5)
    }

    /// Test that when we set the panic threshold, it leaves the rest of the register alone.
    func testSetPanicThresholdIdempotent() {
        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: ~0)

        pwm.panicThreshold = 5

        XCTAssertEqual(registers.dmaConfiguration.rawValue | (~(~0 << 8) << 8), ~0)
    }

    /// Test that we can get the panic threshold.
    func testGetPanicThreshold() {
        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: 5 << 8)

        XCTAssertEqual(pwm.panicThreshold, 5)
    }

    /// Test that we can set the DREQ threshold.
    func testSetDREQThreshold() {
        pwm.dataRequestThreshold = 5

        XCTAssertEqual(registers.dmaConfiguration.rawValue & ~(~0 << 8), 5)
    }

    /// Test that when we set the DREQ threshold, it clears existing bits in the register.
    func testSetDREQThresholdClears() {
        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: ~0)

        pwm.dataRequestThreshold = 5

        XCTAssertEqual(registers.dmaConfiguration.rawValue & ~(~0 << 8), 5)
    }

    /// Test that when we set the DREQ threshold, it leaves the rest of the register alone.
    func testSetDREQThresholdIdempotent() {
        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: ~0)

        pwm.dataRequestThreshold = 5

        XCTAssertEqual(registers.dmaConfiguration.rawValue | ~(~0 << 8), ~0)
    }

    /// Test that we can get the DREQ threshold.
    func testGetDREQThreshold() {
        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: 5)

        XCTAssertEqual(pwm.dataRequestThreshold, 5)
    }

}
