//
//  PWMTests.swift
//  RaspberryPiTests
//
//  Created by Scott James Remnant on 6/7/18.
//

import XCTest

@testable import RaspberryPi

class PWMTests : XCTestCase {

    // MARK: channel

    /// Test that we can create a PWM for channel one.
    func testChannelOne() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        XCTAssertEqual(pwm.channel, .one)
    }

    /// Test that we can change the channel after initialization.
    func testChangeChannel() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.channel = .two

        XCTAssertEqual(pwm.channel, .two)
    }


    // MARK: isEnabled

    /// Test that enabling channel 1 sets the appopriate bit.
    func testSetOneIsEnabled() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.isEnabled = true

        XCTAssertEqual(registers.control.rawValue & 1, 1)
    }

    /// Test that disabling channel 1 clears the appropriate bit.
    func testClearOneIsEnabled() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm.isEnabled = false

        XCTAssertEqual(registers.control.rawValue & 1, 0)
    }

    /// Test that isEnabled is true for channel 1 when the appropriate bit is set.
    func testGetOneIsEnabled() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.control = PWMControl(rawValue: 1)

        XCTAssertEqual(pwm.isEnabled, true)
    }

    /// Test that isEnabled is false for channel 1 when the appropriate bit is not set.
    func testDefaultOneIsEnabled() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm.isEnabled, false)
    }

    /// Test that enabling channel 2 sets the appopriate bit.
    func testSetTwoIsEnabled() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        pwm.isEnabled = true

        XCTAssertEqual((registers.control.rawValue >> 8) & 1, 1)
    }

    /// Test that disabling channel 2 clears the appropriate bit.
    func testClearTwoIsEnabled() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm.isEnabled = false

        XCTAssertEqual((registers.control.rawValue >> 8) & 1, 0)
    }

    /// Test that isEnabled is true for channel 2 when the appropriate bit is set.
    func testGetTwoIsEnabled() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        registers.control = PWMControl(rawValue: 1 << 8)

        XCTAssertEqual(pwm.isEnabled, true)
    }

    /// Test that isEnabled is false for channel 2 when the appropriate bit is not set.
    func testDefaultTwoIsEnabled() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm.isEnabled, false)
    }


    // MARK: mode

    /// Test that we can set the mode of channel 1 to PWM. MODE1 and MSEN1 should be both 0.
    func testSetOneModePWM() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm.mode = .pwm

        XCTAssertEqual((registers.control.rawValue >> 1) & 1, 0)
        XCTAssertEqual((registers.control.rawValue >> 7) & 1, 0)
    }

    /// Test that we can set the mode of channel 1 to Mark-space. MODE1 should be 0 and MSEN1 should be 1.
    func testSetOneModeMarkSpace() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0 ^ (1 << 7))

        pwm.mode = .markSpace

        XCTAssertEqual((registers.control.rawValue >> 1) & 1, 0)
        XCTAssertEqual((registers.control.rawValue >> 7) & 1, 1)
    }

    /// Test that we can set the mode of channel 1 to Serializer. MODE1 should be 1 and MSEN1 should be 0.
    func testSetOneModeSerializer() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0 ^ (1 << 1))

        pwm.mode = .serializer

        XCTAssertEqual((registers.control.rawValue >> 1) & 1, 1)
        XCTAssertEqual((registers.control.rawValue >> 7) & 1, 0)
    }

    /// Test that when MODE1 and MSEN1 are both 0, the returned mode is PWM.
    func testGetOneModePWM() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        XCTAssertEqual(pwm.mode, .pwm)
    }

    /// Test that when MODE1 is 0 and MSEN1 is 1, the returned mode is Mark-space.
    func testGetOneModeMarkSpace() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.control = PWMControl(rawValue: 1 << 7)

        XCTAssertEqual(pwm.mode, .markSpace)
    }

    /// Test that when MODE1 is 1 and MSEN1 is 0, the returned mode is Serializer.
    func testGetOneModeSerializer() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.control = PWMControl(rawValue: 1 << 1)

        XCTAssertEqual(pwm.mode, .serializer)
    }

    /// Test that when MODE1 and MSEN1 are both 1, the returned mode is still Serializer.
    func testGetOneModeSerializerInvalid() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.control = PWMControl(rawValue: (1 << 7) | (1 << 1))

        XCTAssertEqual(pwm.mode, .serializer)
    }

    /// Test that we can set the mode of channel 2 to PWM. MODE2 and MSEN2 should be both 0.
    func testSetTwoModePWM() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm.mode = .pwm

        XCTAssertEqual((registers.control.rawValue >> 9) & 1, 0)
        XCTAssertEqual((registers.control.rawValue >> 15) & 1, 0)
    }

    /// Test that we can set the mode of channel 2 to Mark-space. MODE2 should be 0 and MSEN2 should be 1.
    func testSetTwoModeMarkSpace() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0 ^ (1 << 15))

        pwm.mode = .markSpace

        XCTAssertEqual((registers.control.rawValue >> 9) & 1, 0)
        XCTAssertEqual((registers.control.rawValue >> 15) & 1, 1)
    }

    /// Test that we can set the mode of channel 2 to Serializer. MODE2 should be 1 and MSEN2 should be 0.
    func testSetTwoModeSerializer() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0 ^ (1 << 9))

        pwm.mode = .serializer

        XCTAssertEqual((registers.control.rawValue >> 9) & 1, 1)
        XCTAssertEqual((registers.control.rawValue >> 15) & 1, 0)
    }

    /// Test that when MODE2 and MSEN2 are both 0, the returned mode is PWM.
    func testGetTwoModePWM() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        XCTAssertEqual(pwm.mode, .pwm)
    }

    /// Test that when MODE2 is 0 and MSEN2 is 1, the returned mode is Mark-space.
    func testGetTwoModeMarkSpace() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        registers.control = PWMControl(rawValue: 1 << 15)

        XCTAssertEqual(pwm.mode, .markSpace)
    }

    /// Test that when MODE2 is 1 and MSEN2 is 0, the returned mode is Serializer.
    func testGetTwoModeSerializer() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        registers.control = PWMControl(rawValue: 1 << 9)

        XCTAssertEqual(pwm.mode, .serializer)
    }

    /// Test that when MODE2 and MSEN2 are both 1, the returned mode is still Serializer.
    func testGetTwoModeSerializerInvalid() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        registers.control = PWMControl(rawValue: (1 << 15) | (1 << 9))

        XCTAssertEqual(pwm.mode, .serializer)
    }


    // MARK: range

    /// Test that we can set the range of channel 1.
    func testSetRangeOne() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.range = 50

        XCTAssertEqual(registers.channel1Range, 50)
    }

    /// Test that we can set the range of channel 2.
    func testSetRangeTwo() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        pwm.range = 97

        XCTAssertEqual(registers.channel2Range, 97)
    }

    /// Test that we can get the range of channel 1.
    func testGetRangeOne() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.channel1Range = 87

        XCTAssertEqual(pwm.range, 87)
    }

    /// Test that we can get the range of channel 2.
    func testGetRangeTwo() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        registers.channel2Range = 93

        XCTAssertEqual(pwm.range, 93)
    }


    // MARK: data

    /// Test that we can set the range of channel 1.
    func testSetDataOne() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.data = 50

        XCTAssertEqual(registers.channel1Data, 50)
    }

    /// Test that we can set the range of channel 2.
    func testSetDataTwo() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        pwm.data = 97

        XCTAssertEqual(registers.channel2Data, 97)
    }

    /// Test that we can get the range of channel 1.
    func testGetDataOne() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.channel1Data = 87

        XCTAssertEqual(pwm.data, 87)
    }

    /// Test that we can get the range of channel 2.
    func testGetDataTwo() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        registers.channel2Data = 93

        XCTAssertEqual(pwm.data, 93)
    }


    // MARK: silenceBit

    /// Test that setting the silence bit of channel 1 to high sets the appopriate bit.
    func testSetOneSilenceBitHigh() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.silenceBit = .high

        XCTAssertEqual((registers.control.rawValue >> 3) & 1, 1)
    }

    /// Test that setting the silence bit of channel 1 to low clears the appropriate bit.
    func testSetOneSilenceBitLow() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm.silenceBit = .low

        XCTAssertEqual((registers.control.rawValue >> 3) & 1, 0)
    }

    /// Test that silenceBit is .high for channel 1 when the appropriate bit is set.
    func testGetOneSilenceBit() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.control = PWMControl(rawValue: 1 << 3)

        XCTAssertEqual(pwm.silenceBit, .high)
    }

    /// Test that silenceBit is .low for channel 1 when the appropriate bit is not set.
    func testDefaultOneSilenceBit() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm.silenceBit, .low)
    }

    /// Test that setting the silence bit of channel 2 to high sets the appopriate bit.
    func testSetTwoSilenceBit() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        pwm.silenceBit = .high

        XCTAssertEqual((registers.control.rawValue >> 11) & 1, 1)
    }

    /// Test that setting the silence bit of channel 2 to low clears the appropriate bit.
    func testClearTwoSilenceBit() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm.silenceBit = .low

        XCTAssertEqual((registers.control.rawValue >> 11) & 1, 0)
    }

    /// Test that silenceBit is .high for channel 2 when the appropriate bit is set.
    func testGetTwoSilenceBit() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        registers.control = PWMControl(rawValue: 1 << 11)

        XCTAssertEqual(pwm.silenceBit, .high)
    }

    /// Test that silenceBit is .low for channel 2 when the appropriate bit is not set.
    func testDefaultTwoSilenceBit() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm.silenceBit, .low)
    }


    // MARK: invertPolarity

    /// Test that inverting polarity of channel 1 sets the appopriate bit.
    func testSetOneInvertPolarity() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.invertPolarity = true

        XCTAssertEqual((registers.control.rawValue >> 4) & 1, 1)
    }

    /// Test that using normal polarity for channel 1 clears the appropriate bit.
    func testClearOneInvertPolarity() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm.invertPolarity = false

        XCTAssertEqual((registers.control.rawValue >> 4) & 1, 0)
    }

    /// Test that invertPolarity is true for channel 1 when the appropriate bit is set.
    func testGetOneInvertPolarity() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.control = PWMControl(rawValue: 1 << 4)

        XCTAssertEqual(pwm.invertPolarity, true)
    }

    /// Test that invertPolarity is false for channel 1 when the appropriate bit is not set.
    func testDefaultOneInvertPolarity() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm.invertPolarity, false)
    }

    /// Test that inverting polarity of channel 2 sets the appopriate bit.
    func testSetTwoInvertPolarity() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        pwm.invertPolarity = true

        XCTAssertEqual((registers.control.rawValue >> 12) & 1, 1)
    }

    /// Test that using normal polarity for channel 2 clears the appropriate bit.
    func testClearTwoInvertPolarity() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm.invertPolarity = false

        XCTAssertEqual((registers.control.rawValue >> 12) & 1, 0)
    }

    /// Test that invertPolarity is true for channel 2 when the appropriate bit is set.
    func testGetTwoInvertPolarity() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        registers.control = PWMControl(rawValue: 1 << 12)

        XCTAssertEqual(pwm.invertPolarity, true)
    }

    /// Test that invertPolarity is false for channel 2 when the appropriate bit is not set.
    func testDefaultTwoInvertPolarity() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm.invertPolarity, false)
    }


    // MARK: channel status

    /// Test that the channel 1 state status bit is returned via isTransmitting.
    func testOneIsTransmitting() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.status = PWMStatus(rawValue: 1 << 9)

        XCTAssertEqual(pwm.isTransmitting, true)
    }

    /// Test that the channel 2 state status bit is returned via isTransmitting.
    func testTwoIsTransmitting() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        registers.status = PWMStatus(rawValue: 1 << 10)

        XCTAssertEqual(pwm.isTransmitting, true)
    }

    /// Test that the default of channel 1 isTransmitting is false.
    func testDefaultOneIsTransmitting() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        XCTAssertEqual(pwm.isTransmitting, false)
    }

    /// Test that the default of channel 2 isTransmitting is false.
    func testDefaultTwoIsTransmitting() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        XCTAssertEqual(pwm.isTransmitting, false)
    }

    /// Test that the channel 1 gap occurred status bit is returned via isTransmissionGap.
    func testOneIsTransmissionGap() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.status = PWMStatus(rawValue: 1 << 4)

        XCTAssertEqual(pwm.isTransmissionGap, true)
    }

    /// Test that the channel 2 gap occurred status bit is returned via isTransmissionGap.
    func testTwoIsTransmissionGap() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        registers.status = PWMStatus(rawValue: 1 << 5)

        XCTAssertEqual(pwm.isTransmissionGap, true)
    }

    /// Test that the default channel 1 isTransmissionGap is false.
    func testDefaultOneIsTransmissionGap() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        XCTAssertEqual(pwm.isTransmissionGap, false)
    }

    /// Test that the default channel 2 isTransmissionGap is false.
    func testDefaultTwoIsTransmissionGap() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        XCTAssertEqual(pwm.isTransmissionGap, false)
    }

    /// Test the the channel 1 gap occurred status bit is written when clearing.
    func testClearOneIsTransmissionGap() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.isTransmissionGap = false

        XCTAssertEqual((registers.status.rawValue >> 4) & 1, 1)
    }

    /// Test the the channel 2 gap occurred status bit is written when clearing.
    func testClearTwoIsTransmissionGap() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        pwm.isTransmissionGap = false

        XCTAssertEqual((registers.status.rawValue >> 5) & 1, 1)
    }

    /// Test that writing true to channel 1 isTransmissionGap has no effect.
    func testOneIsTransmissionGapNoop() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.isTransmissionGap = true

        XCTAssertEqual(registers.status.rawValue, 0)
    }

    /// Test that writing true to channel 2 isTransmissionGap has no effect.
    func testTwoIsTransmissionGapNoop() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        pwm.isTransmissionGap = true

        XCTAssertEqual(registers.status.rawValue, 0)
    }


    // MARK: bus error

    /// Test that the bus error status bit is returned via isBusError.
    func testIsBusError() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.status = PWMStatus(rawValue: 1 << 8)

        XCTAssertEqual(pwm.isBusError, true)
    }

    /// Test isBusError defaults to false.
    func testDefaultIsBusError() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        XCTAssertEqual(pwm.isBusError, false)
    }

    /// Test that the bus error is cleared by writing false to isBusError.
    func testClearIsBusError() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.isBusError = false

        XCTAssertEqual((registers.status.rawValue >> 8) & 1, 1)
    }

    /// Test that writing true to isBusError is a no-op.
    func testIsBusErrorNoop() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.isBusError = true

        XCTAssertEqual(registers.status.rawValue, 0)
    }


    // MARK: useFifo

    /// Test that using the fifo for channel 1 sets the appopriate bit.
    func testSetOneUseFifo() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.useFifo = true

        XCTAssertEqual((registers.control.rawValue >> 5) & 1, 1)
    }

    /// Test that using data for channel 1 clears the appropriate bit.
    func testClearOneUseFifo() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm.useFifo = false

        XCTAssertEqual((registers.control.rawValue >> 5) & 1, 0)
    }

    /// Test that useFifo is true for channel 1 when the appropriate bit is set.
    func testGetOneUseFifo() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.control = PWMControl(rawValue: 1 << 5)

        XCTAssertEqual(pwm.useFifo, true)
    }

    /// Test that useFifo is false for channel 1 when the appropriate bit is not set.
    func testDefaultOneUseFifo() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm.useFifo, false)
    }

    /// Test that using the fifo for channel 2 sets the appopriate bit.
    func testSetTwoUseFifo() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        pwm.useFifo = true

        XCTAssertEqual((registers.control.rawValue >> 13) & 1, 1)
    }

    /// Test that using data for channel 2 clears the appropriate bit.
    func testClearTwoUseFifo() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm.useFifo = false

        XCTAssertEqual((registers.control.rawValue >> 13) & 1, 0)
    }

    /// Test that useFifo is true for channel 2 when the appropriate bit is set.
    func testGetTwoUseFifo() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        registers.control = PWMControl(rawValue: 1 << 13)

        XCTAssertEqual(pwm.useFifo, true)
    }

    /// Test that useFifo is false for channel 2 when the appropriate bit is not set.
    func testDefaultTwoUseFifo() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm.useFifo, false)
    }


    // MARK: fifoInput

    /// Test that we can write to the FiFo.
    func testFifoInput() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.fifoInput = 99

        XCTAssertEqual(registers.fifoInput, 99)
    }

    /// Test that reading from the fifo input always returns 0.
    func testGetFifoInput() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.fifoInput = 104

        XCTAssertEqual(pwm.fifoInput, 0)
    }


    // MARK: clearFifo

    /// Test that calling the method sets the appropriate bit in the control register.
    func testClearFifo() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.clearFifo()

        XCTAssertEqual((registers.control.rawValue >> 6) & 1, 1)
    }


    // MARK: repeatFifoData

    /// Test that repeating fifo data for channel 1 sets the appopriate bit.
    func testSetOneRepeatFifoData() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.repeatFifoData = true

        XCTAssertEqual((registers.control.rawValue >> 2) & 1, 1)
    }

    /// Test that silence for channel 1 clears the appropriate bit.
    func testClearOneRepeatFifoData() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm.repeatFifoData = false

        XCTAssertEqual((registers.control.rawValue >> 2) & 1, 0)
    }

    /// Test that repeatFifoData is true for channel 1 when the appropriate bit is set.
    func testGetOneRepeatFifoData() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.control = PWMControl(rawValue: 1 << 2)

        XCTAssertEqual(pwm.repeatFifoData, true)
    }

    /// Test that repeatFifoData is false for channel 1 when the appropriate bit is not set.
    func testDefaultOneRepeatFifoData() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm.repeatFifoData, false)
    }

    /// Test that repeating fifo data for channel 2 sets the appopriate bit.
    func testSetTwoRepeatFifoData() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        pwm.repeatFifoData = true

        XCTAssertEqual((registers.control.rawValue >> 10) & 1, 1)
    }

    /// Test that silence for channel 2 clears the appropriate bit.
    func testClearTwoRepeatFifoData() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        // Corrupt the register to ensure bits are cleared.
        registers.control = PWMControl(rawValue: ~0)

        pwm.repeatFifoData = false

        XCTAssertEqual((registers.control.rawValue >> 10) & 1, 0)
    }

    /// Test that repeatFifoData is true for channel 2 when the appropriate bit is set.
    func testGetTwoRepeatFifoData() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        registers.control = PWMControl(rawValue: 1 << 10)

        XCTAssertEqual(pwm.repeatFifoData, true)
    }

    /// Test that repeatFifoData is false for channel 2 when the appropriate bit is not set.
    func testDefaultTwoRepeatFifoData() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .two, registers: &registers)

        registers.control = PWMControl(rawValue: 0)

        XCTAssertEqual(pwm.repeatFifoData, false)
    }


    // MARK: FIFO status

    /// Test that the fifo empty status bit is returned via isFifoEmpty.
    func testIsFifoEmpty() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.status = PWMStatus(rawValue: 1 << 1)

        XCTAssertEqual(pwm.isFifoEmpty, true)
    }

    /// Test isFifoEmpty defaults to false.
    func testDefaultIsFifoEmpty() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        XCTAssertEqual(pwm.isFifoEmpty, false)
    }

    /// Test that the fifo read error status bit is returned via isFifoReadWhenEmpty.
    func testIsFifoReadWhenEmpty() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.status = PWMStatus(rawValue: 1 << 3)

        XCTAssertEqual(pwm.isFifoReadWhenEmpty, true)
    }

    /// Test isFifoReadWhenEmpty defaults to false.
    func testDefaultIsFifoReadWhenEmpty() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        XCTAssertEqual(pwm.isFifoReadWhenEmpty, false)
    }

    /// Test that the fifo read error is cleared by writing false to isFifoReadWhenEmpty.
    func testClearIsFifoReadWhenEmpty() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.isFifoReadWhenEmpty = false

        XCTAssertEqual((registers.status.rawValue >> 3) & 1, 1)
    }

    /// Test that writing true to isFifoReadWhenEmpty is a no-op.
    func testIsFifoReadWhenEmptyNoop() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.isFifoReadWhenEmpty = true

        XCTAssertEqual(registers.status.rawValue, 0)
    }

    /// Test that the fifo empty status bit is returned via isFifoFull.
    func testIsFifoFull() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.status = PWMStatus(rawValue: 1)

        XCTAssertEqual(pwm.isFifoFull, true)
    }

    /// Test isFifoFull defaults to false.
    func testDefaultIsFifoFull() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        XCTAssertEqual(pwm.isFifoFull, false)
    }

    /// Test that the fifo write error status bit is returned via isFifoWrittenWhenFull.
    func testIsFifoWrittenWhenFull() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.status = PWMStatus(rawValue: 1 << 2)

        XCTAssertEqual(pwm.isFifoWrittenWhenFull, true)
    }

    /// Test isFifoWrittenWhenFull defaults to false.
    func testDefaultIsFifoWrittenWhenFull() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        XCTAssertEqual(pwm.isFifoWrittenWhenFull, false)
    }

    /// Test that the fifo write error is cleared by writing false to isFifoWrittenWhenFull.
    func testClearIsFifoWrittenWhenFull() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.isFifoWrittenWhenFull = false

        XCTAssertEqual((registers.status.rawValue >> 2) & 1, 1)
    }

    /// Test that writing true to isFifoWrittenWhenFull is a no-op.
    func testIsFifoWrittenWhenFullNoop() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.isFifoWrittenWhenFull = true

        XCTAssertEqual(registers.status.rawValue, 0)
    }


    // MARK: DMA Configuration

    /// Test that enabling DMA sets the appopriate bit.
    func testSetIsDMAEnabled() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.isDMAEnabled = true

        XCTAssertEqual((registers.dmaConfiguration.rawValue >> 31) & 1, 1)
    }

    /// Test that enabling DMA doesn't corrupt the thresholds.
    func testSetIsDMAEnabledIdempotent() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: (3 << 8) | 5)
        pwm.isDMAEnabled = true

        XCTAssertEqual(pwm.panicThreshold, 3)
        XCTAssertEqual(pwm.dreqThreshold, 5)
    }

    /// Test that disabling DMA clears the appropriate bit.
    func testClearIsDMAEnabled() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        // Corrupt the register to ensure bits are cleared.
        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: ~0)

        pwm.isDMAEnabled = false

        XCTAssertEqual((registers.dmaConfiguration.rawValue >> 31) & 1, 0)
    }

    /// Test that disabling DMA doesn't corrupt the thresholds.
    func testClearIsDMAEnabledIdempotent() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: (1 << 31) | (3 << 8) | 5)
        pwm.isDMAEnabled = false

        XCTAssertEqual(pwm.panicThreshold, 3)
        XCTAssertEqual(pwm.dreqThreshold, 5)
    }

    /// Test that isDMAEnabled is true when the appropriate bit is set.
    func testGetIsDMAEnabled() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: 1 << 31)

        XCTAssertEqual(pwm.isDMAEnabled, true)
    }

    /// Test that isDMAEnabled is false when the appropriate bit is not set.
    func testDefaultIsDMAEnabled() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        XCTAssertEqual(pwm.isDMAEnabled, false)
    }

    /// Test that we can set the panic threshold.
    func testSetPanicThreshold() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.panicThreshold = 5

        XCTAssertEqual((registers.dmaConfiguration.rawValue >> 8) & ~(~0 << 8), 5)
    }

    /// Test that when we set the panic threshold, it clears existing bits in the register.
    func testSetPanicThresholdClears() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: ~0)

        pwm.panicThreshold = 5

        XCTAssertEqual((registers.dmaConfiguration.rawValue >> 8) & ~(~0 << 8), 5)
    }

    /// Test that when we set the panic threshold, it leaves the rest of the register alone.
    func testSetPanicThresholdIdempotent() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: ~0)

        pwm.panicThreshold = 5

        XCTAssertEqual(registers.dmaConfiguration.rawValue | (~(~0 << 8) << 8), ~0)
    }

    /// Test that we can get the panic threshold.
    func testGetPanicThreshold() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: 5 << 8)

        XCTAssertEqual(pwm.panicThreshold, 5)
    }

    /// Test that we can set the DREQ threshold.
    func testSetDREQThreshold() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        pwm.dreqThreshold = 5

        XCTAssertEqual(registers.dmaConfiguration.rawValue & ~(~0 << 8), 5)
    }

    /// Test that when we set the DREQ threshold, it clears existing bits in the register.
    func testSetDREQThresholdClears() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: ~0)

        pwm.dreqThreshold = 5

        XCTAssertEqual(registers.dmaConfiguration.rawValue & ~(~0 << 8), 5)
    }

    /// Test that when we set the DREQ threshold, it leaves the rest of the register alone.
    func testSetDREQThresholdIdempotent() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: ~0)

        pwm.dreqThreshold = 5

        XCTAssertEqual(registers.dmaConfiguration.rawValue | ~(~0 << 8), ~0)
    }

    /// Test that we can get the DREQ threshold.
    func testGetDREQThreshold() {
        var registers = PWM.Registers()
        let pwm = PWM(channel: .one, registers: &registers)

        registers.dmaConfiguration = PWMDMAConfiguration(rawValue: 5)

        XCTAssertEqual(pwm.dreqThreshold, 5)
    }

}
