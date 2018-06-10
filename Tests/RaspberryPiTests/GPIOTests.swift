//
//  GPIOTests.swift
//  RaspberryPiTests
//
//  Created by Scott James Remnant on 5/31/18.
//

import XCTest

@testable import RaspberryPi

class GPIOTests : XCTestCase {

    // MARK: Layout

    /// Test that the layout of the Registers struct matches hardware.
    func testRegistersLayout() {
        XCTAssertEqual(MemoryLayout<GPIO.Registers>.size, 0xa4)

        #if swift(>=4.1.9)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIO.Registers.functionSelect), 0x00)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIO.Registers.outputSet), 0x1c)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIO.Registers.outputClear), 0x28)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIO.Registers.level), 0x34)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIO.Registers.eventDetectStatus), 0x40)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIO.Registers.risingEdgeDetectEnable), 0x4c)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIO.Registers.fallingEdgeDetectEnable), 0x58)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIO.Registers.highDetectEnable), 0x64)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIO.Registers.lowDetectEnable), 0x70)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIO.Registers.asyncRisingEdgeDetectEnable), 0x7c)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIO.Registers.asyncFallingEdgeDetectEnable), 0x88)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIO.Registers.pullUpDownEnable), 0x94)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIO.Registers.pullUpDownEnableClock), 0x98)
        #endif

        XCTAssertEqual(MemoryLayout<GPIOFunctionSelect>.size, 0x1c)
        #if swift(>=4.1.9)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIOFunctionSelect.field0), 0x00)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIOFunctionSelect.field1), 0x04)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIOFunctionSelect.field2), 0x08)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIOFunctionSelect.field3), 0x0c)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIOFunctionSelect.field4), 0x10)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIOFunctionSelect.field5), 0x14)
        #endif

        XCTAssertEqual(MemoryLayout<GPIOBitField>.size, 0x0c)
        #if swift(>=4.1.9)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIOBitField.field0), 0x00)
        XCTAssertEqual(MemoryLayout.offset(of: \GPIOBitField.field1), 0x04)
        #endif
    }


    // MARK: Collection conformance

    /// Test that the collection implementation produces a correct count.
    func testCount() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        XCTAssertEqual(gpio.count, 54)
    }

    /// Test that the start index of the collection is zero.
    func testStartIndex() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        XCTAssertEqual(gpio.startIndex, 0)
    }

    /// Test that the end index of the collection is the count.
    func testEndIndex() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        XCTAssertEqual(gpio.endIndex, 54)
    }

    /// Test that the collection implementation has correct indexes.
    func testIndexes() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        XCTAssertEqual(Array(gpio.indices), Array(0..<54))
    }


    // MARK: Function Select

    /// Test that we can set the first GPIO to input.
    func testSetInputFunction() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.functionSelect.field0 = ~0

        gpio[0].function = .input

        XCTAssertEqual(registers.functionSelect.field0 & 0b111, 0b000)
    }

    /// Test that we can check the first GPIO is set to input.
    func testGetInputFunction() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field0 = 0b000

        XCTAssertEqual(gpio[0].function, .input)
    }

    /// Test that we can set the first GPIO to output.
    func testSetOutputFunction() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[0].function = .output

        XCTAssertEqual(registers.functionSelect.field0 & 0b111, 0b001)
    }

    /// Test that we can check the first GPIO is set to output.
    func testGetOutputFunction() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field0 = 0b001

        XCTAssertEqual(gpio[0].function, .output)
    }

    /// Test that we can set the first GPIO to alternate function 0.
    func testSetAlternateFunction0() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[0].function = .alternateFunction0

        XCTAssertEqual(registers.functionSelect.field0 & 0b111, 0b100)
    }

    /// Test that we can check the first GPIO is set to alternate function 0.
    func testGetAlternateFunction0() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field0 = 0b100

        XCTAssertEqual(gpio[0].function, .alternateFunction0)
    }

    /// Test that we can set the first GPIO to alternate function 1.
    func testSetAlternateFunction1() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[0].function = .alternateFunction1

        XCTAssertEqual(registers.functionSelect.field0 & 0b111, 0b101)
    }

    /// Test that we can check the first GPIO is set to alternate function 1.
    func testGetAlternateFunction1() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field0 = 0b101

        XCTAssertEqual(gpio[0].function, .alternateFunction1)
    }

    /// Test that we can set the first GPIO to alternate function 2.
    func testSetAlternateFunction2() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[0].function = .alternateFunction2

        XCTAssertEqual(registers.functionSelect.field0 & 0b111, 0b110)
    }

    /// Test that we can check the first GPIO is set to alternate function 2.
    func testGetAlternateFunction2() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field0 = 0b110

        XCTAssertEqual(gpio[0].function, .alternateFunction2)
    }

    /// Test that we can set the first GPIO to alternate function 3.
    func testSetAlternateFunction3() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[0].function = .alternateFunction3

        XCTAssertEqual(registers.functionSelect.field0 & 0b111, 0b111)
    }

    /// Test that we can check the first GPIO is set to alternate function 3.
    func testGetAlternateFunction3() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field0 = 0b111

        XCTAssertEqual(gpio[0].function, .alternateFunction3)
    }

    /// Test that we can set the first GPIO to alternate function 4.
    func testSetAlternateFunction4() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[0].function = .alternateFunction4

        XCTAssertEqual(registers.functionSelect.field0 & 0b111, 0b011)
    }

    /// Test that we can check the first GPIO is set to alternate function 4.
    func testGetAlternateFunction4() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field0 = 0b011

        XCTAssertEqual(gpio[0].function, .alternateFunction4)
    }

    /// Test that we can set the first GPIO to alternate function 5.
    func testSetAlternateFunction5() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[0].function = .alternateFunction5

        XCTAssertEqual(registers.functionSelect.field0 & 0b111, 0b010)
    }

    /// Test that we can check the first GPIO is set to alternate function 5.
    func testGetAlternateFunction5() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field0 = 0b010

        XCTAssertEqual(gpio[0].function, .alternateFunction5)
    }

    /// Test that we can set the last GPIO in the first field to input.
    func testSetField0LastFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.functionSelect.field0 = ~0

        gpio[9].function = .input

        XCTAssertEqual((registers.functionSelect.field0 >> 27) & 0b111, 0b000)
    }

    /// Test that we can get the setting of the last GPIO in the first field.
    func testGetField0LastFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field0 = 0b001 << 27

        XCTAssertEqual(gpio[9].function, .output)
    }

    /// Test that we can set the first GPIO in the second field to input.
    func testSetField1FirstFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.functionSelect.field1 = ~0

        gpio[10].function = .input

        XCTAssertEqual(registers.functionSelect.field1 & 0b111, 0b000)
    }

    /// Test that we can get the setting of the first GPIO in the second field.
    func testGetField1FirstFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field1 = 0b001

        XCTAssertEqual(gpio[10].function, .output)
    }

    /// Test that we can set the last GPIO in the second field to input.
    func testSetField1LastFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.functionSelect.field1 = ~0

        gpio[19].function = .input

        XCTAssertEqual((registers.functionSelect.field1 >> 27) & 0b111, 0b000)
    }

    /// Test that we can get the setting of the last GPIO in the second field.
    func testGetField1LastFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field1 = 0b001 << 27

        XCTAssertEqual(gpio[19].function, .output)
    }

    /// Test that we can set the first GPIO in the third field to input.
    func testSetField2FirstFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.functionSelect.field2 = ~0

        gpio[20].function = .input

        XCTAssertEqual(registers.functionSelect.field2 & 0b111, 0b000)
    }

    /// Test that we can get the setting of the first GPIO in the third field.
    func testGetField2FirstFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field2 = 0b001

        XCTAssertEqual(gpio[20].function, .output)
    }

    /// Test that we can set the last GPIO in the third field to input.
    func testSetField2LastFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.functionSelect.field2 = ~0

        gpio[29].function = .input

        XCTAssertEqual((registers.functionSelect.field2 >> 27) & 0b111, 0b000)
    }

    /// Test that we can get the setting of the last GPIO in the third field.
    func testGetField2LastFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field2 = 0b001 << 27

        XCTAssertEqual(gpio[29].function, .output)
    }

    /// Test that we can set the first GPIO in the fourth field to input.
    func testSetField3FirstFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.functionSelect.field3 = ~0

        gpio[30].function = .input

        XCTAssertEqual(registers.functionSelect.field3 & 0b111, 0b000)
    }

    /// Test that we can get the setting of the first GPIO in the fourth field.
    func testGetField3FirstFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field3 = 0b001

        XCTAssertEqual(gpio[30].function, .output)
    }

    /// Test that we can set the last GPIO in the fourth field to input.
    func testSetField3LastFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.functionSelect.field3 = ~0

        gpio[39].function = .input

        XCTAssertEqual((registers.functionSelect.field1 >> 27) & 0b111, 0b000)
    }

    /// Test that we can get the setting of the last GPIO in the fourth field.
    func testGetField3LastFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field3 = 0b001 << 27

        XCTAssertEqual(gpio[39].function, .output)
    }

    /// Test that we can set the first GPIO in the fifth field to input.
    func testSetField4FirstFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.functionSelect.field4 = ~0

        gpio[40].function = .input

        XCTAssertEqual(registers.functionSelect.field4 & 0b111, 0b000)
    }

    /// Test that we can get the setting of the first GPIO in the fourth field.
    func testGetField4FirstFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field4 = 0b001

        XCTAssertEqual(gpio[40].function, .output)
    }

    /// Test that we can set the last GPIO in the fourth field to input.
    func testSetField4LastFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.functionSelect.field4 = ~0

        gpio[49].function = .input

        XCTAssertEqual((registers.functionSelect.field4 >> 27) & 0b111, 0b000)
    }

    /// Test that we can get the setting of the last GPIO in the fourth field.
    func testGetField4LastFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field4 = 0b001 << 27

        XCTAssertEqual(gpio[49].function, .output)
    }

    /// Test that we can set the first GPIO in the fifth field to input.
    func testSetField5FirstFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.functionSelect.field5 = ~0

        gpio[50].function = .input

        XCTAssertEqual(registers.functionSelect.field5 & 0b111, 0b000)
    }

    /// Test that we can get the setting of the first GPIO in the fifth field.
    func testGetField5FirstFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field5 = 0b001

        XCTAssertEqual(gpio[50].function, .output)
    }

    /// Test that we can set the last GPIO to input.
    func testSetLastFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.functionSelect.field5 = ~0

        gpio[53].function = .input

        XCTAssertEqual((registers.functionSelect.field5 >> 9) & 0b111, 0b000)
    }

    /// Test that we can get the setting of the last GPIO.
    func testGetLastFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.functionSelect.field5 = 0b001 << 9

        XCTAssertEqual(gpio[53].function, .output)
    }

    /// Test that we when we set a GPIO, it leaves the other bits alone.
    func testDiscreteFunctionSelect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.functionSelect.field0 = ~0

        gpio[0].function = .input

        XCTAssertEqual(registers.functionSelect.field0 | 0b111, ~0)
        XCTAssertEqual(registers.functionSelect.field1, 0)
        XCTAssertEqual(registers.functionSelect.field2, 0)
        XCTAssertEqual(registers.functionSelect.field3, 0)
        XCTAssertEqual(registers.functionSelect.field4, 0)
        XCTAssertEqual(registers.functionSelect.field5, 0)
    }


    // MARK: Value

    /// That that setting the first GPIO sets the appropriate Pin Output Set bit.
    func testSetValue() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[0].value = true

        XCTAssertEqual(registers.outputSet.field0 & 1, 1)
    }

    /// That that setting the first GPIO sets the appropriate Pin Output Clear bit.
    func testClearValue() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[0].value = false

        XCTAssertEqual(registers.outputClear.field0 & 1, 1)
    }

    /// That that getting the first GPIO returns from the appropriate Pin Level.
    func testGetValue() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.level.field0 = 1

        XCTAssertEqual(gpio[0].value, true)
    }

    /// That that setting the last GPIO in the first field sets the appropriate Pin Output Set bit.
    func testSetField0LastValue() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[31].value = true

        XCTAssertEqual((registers.outputSet.field0 >> 31) & 1, 1)
    }

    /// That that setting the last GPIO in the first field sets the appropriate Pin Output Clear bit.
    func testClearField0LastValue() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[31].value = false

        XCTAssertEqual((registers.outputClear.field0 >> 31) & 1, 1)
    }

    /// That that getting the last GPIO in the first field returns from the appropriate Pin Level.
    func testGetField0LastValue() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.level.field0 = 1 << 31

        XCTAssertEqual(gpio[31].value, true)
    }

    /// That that setting the first GPIO in the second field sets the appropriate Pin Output Set bit.
    func testSetField1FirstValue() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[32].value = true

        XCTAssertEqual(registers.outputSet.field1 & 1, 1)
    }

    /// That that setting the first GPIO in the second field sets the appropriate Pin Output Clear bit.
    func testClearField1FirstValue() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[32].value = false

        XCTAssertEqual(registers.outputClear.field1 & 1, 1)
    }

    /// That that getting the first GPIO in the second field returns from the appropriate Pin Level.
    func testGetField1FirstValue() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.level.field1 = 1

        XCTAssertEqual(gpio[32].value, true)
    }

    /// That that setting the last GPIO sets the appropriate Pin Output Set bit.
    func testSetLastValue() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[53].value = true

        XCTAssertEqual((registers.outputSet.field1 >> 21) & 1, 1)
    }

    /// That that setting the last GPIO sets the appropriate Pin Output Clear bit.
    func testClearLastValue() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[53].value = false

        XCTAssertEqual((registers.outputClear.field1 >> 21) & 1, 1)
    }

    /// That that getting the last GPIO returns from the appropriate Pin Level.
    func testGetLastValue() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.level.field1 = 1 << 21

        XCTAssertEqual(gpio[53].value, true)
    }


    // MARK: Event Detect

    /// Test that an event detect status can be retrieved.
    func testEventDetect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.eventDetectStatus.field0 = 1

        XCTAssertEqual(gpio[0].isEventDetected, true)
    }

    /// Test that writing false clears the event detect flag by writing 1 to it.
    func testEventDetectClear() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[0].isEventDetected = false

        XCTAssertEqual(registers.eventDetectStatus.field0 & 1, 1)
    }

    /// Test that writing true does not change the registers.
    func testEventDetectTrueNoop() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[0].isEventDetected = true

        XCTAssertEqual(registers.eventDetectStatus.field0, 0)
    }


    // MARK: Edge Detect.

    /// Test that we can set the edge detect registers to both 0.
    func testSetEdgeDetectNone() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.risingEdgeDetectEnable.field0 = ~0
        registers.fallingEdgeDetectEnable.field0 = ~0

        gpio[0].edgeDetect = .none

        XCTAssertEqual(registers.risingEdgeDetectEnable.field0 & 1, 0)
        XCTAssertEqual(registers.fallingEdgeDetectEnable.field0 & 1, 0)
    }

    /// Test that .none is returned when both edge detect registers are 0.
    func testGetEdgeDetectNone() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        XCTAssertEqual(gpio[0].edgeDetect,  .none)
    }

    /// Test that we can set the edge detect registers to just rising.
    func testSetEdgeDetectRising() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure the right of the bits go to zero.
        registers.fallingEdgeDetectEnable.field0 = ~0

        gpio[0].edgeDetect = .rising

        XCTAssertEqual(registers.risingEdgeDetectEnable.field0 & 1, 1)
        XCTAssertEqual(registers.fallingEdgeDetectEnable.field0 & 1, 0)
    }

    /// Test that .rising is returned when the rising register is 1 and the falling is 0.
    func testGetEdgeDetectRising() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.risingEdgeDetectEnable.field0 = 1

        XCTAssertEqual(gpio[0].edgeDetect, .rising)
    }

    /// Test that we can set the edge detect registers to just falling.
    func testSetEdgeDetectFalling() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure the right of the bits go to zero.
        registers.risingEdgeDetectEnable.field0 = ~0

        gpio[0].edgeDetect = .falling

        XCTAssertEqual(registers.risingEdgeDetectEnable.field0 & 1, 0)
        XCTAssertEqual(registers.fallingEdgeDetectEnable.field0 & 1, 1)
    }

    /// Test that .falling is returned when the falling register is 1 and the rising is 0.
    func testGetEdgeDetectFalling() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.fallingEdgeDetectEnable.field0 = 1

        XCTAssertEqual(gpio[0].edgeDetect, .falling)
    }

    /// Test that we can set the edge detect registers to detect both 1.
    func testSetEdgeDetectBoth() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[0].edgeDetect = .both

        XCTAssertEqual(registers.risingEdgeDetectEnable.field0 & 1, 1)
        XCTAssertEqual(registers.fallingEdgeDetectEnable.field0 & 1, 1)
    }

    /// Test that .both is returned when both edge detect registers are 0.
    func testGetEdgeDetectBoth() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.risingEdgeDetectEnable.field0 = 1
        registers.fallingEdgeDetectEnable.field0 = 1

        XCTAssertEqual(gpio[0].edgeDetect, .both)
    }

    /// Test that we when we set a GPIO edge detect, it leaves the other bits alone.
    func testDiscreteEdgeDetect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.risingEdgeDetectEnable.field0 = ~0
        registers.risingEdgeDetectEnable.field1 = ~0
        registers.fallingEdgeDetectEnable.field0 = ~0
        registers.fallingEdgeDetectEnable.field1 = ~0

        gpio[0].edgeDetect = .none

        XCTAssertEqual(registers.risingEdgeDetectEnable.field0 | 0b1, ~0)
        XCTAssertEqual(registers.risingEdgeDetectEnable.field1, ~0)
        XCTAssertEqual(registers.fallingEdgeDetectEnable.field0 | 0b1, ~0)
        XCTAssertEqual(registers.fallingEdgeDetectEnable.field1, ~0)
    }


    // MARK: Level Detect.

    /// Test that we can set the edge detect registers to both 0.
    func testSetLevelDetectNone() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.highDetectEnable.field0 = ~0
        registers.lowDetectEnable.field0 = ~0

        gpio[0].levelDetect = .none

        XCTAssertEqual(registers.highDetectEnable.field0 & 1, 0)
        XCTAssertEqual(registers.lowDetectEnable.field0 & 1, 0)
    }

    /// Test that .none is returned when both edge detect registers are 0.
    func testGetLevelDetectNone() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        XCTAssertEqual(gpio[0].levelDetect,  .none)
    }

    /// Test that we can set the edge detect registers to just high.
    func testSetLevelDetectHigh() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure the right of the bits go to zero.
        registers.lowDetectEnable.field0 = ~0

        gpio[0].levelDetect = .high

        XCTAssertEqual(registers.highDetectEnable.field0 & 1, 1)
        XCTAssertEqual(registers.lowDetectEnable.field0 & 1, 0)
    }

    /// Test that .high is returned when the high register is 1 and the low is 0.
    func testGetLevelDetectHigh() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.highDetectEnable.field0 = 1

        XCTAssertEqual(gpio[0].levelDetect, .high)
    }

    /// Test that we can set the edge detect registers to just low.
    func testSetLevelDetectFalling() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure the right of the bits go to zero.
        registers.highDetectEnable.field0 = ~0

        gpio[0].levelDetect = .low

        XCTAssertEqual(registers.highDetectEnable.field0 & 1, 0)
        XCTAssertEqual(registers.lowDetectEnable.field0 & 1, 1)
    }

    /// Test that .low is returned when the low register is 1 and the high is 0.
    func testGetLevelDetectFalling() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.lowDetectEnable.field0 = 1

        XCTAssertEqual(gpio[0].levelDetect, .low)
    }

    /// Test that we when we set a GPIO level detect, it leaves the other bits alone.
    func testDiscreteLevelDetect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.highDetectEnable.field0 = ~0
        registers.highDetectEnable.field1 = ~0
        registers.lowDetectEnable.field0 = ~0
        registers.lowDetectEnable.field1 = ~0

        gpio[0].levelDetect = .none

        XCTAssertEqual(registers.highDetectEnable.field0 | 0b1, ~0)
        XCTAssertEqual(registers.highDetectEnable.field1, ~0)
        XCTAssertEqual(registers.lowDetectEnable.field0 | 0b1, ~0)
        XCTAssertEqual(registers.lowDetectEnable.field1, ~0)
    }


    // MARK: Asynchronous Edge Detect.

    /// Test that we can set the edge detect registers to both 0.
    func testSetAsyncEdgeDetectNone() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.asyncRisingEdgeDetectEnable.field0 = ~0
        registers.asyncFallingEdgeDetectEnable.field0 = ~0

        gpio[0].asyncEdgeDetect = .none

        XCTAssertEqual(registers.asyncRisingEdgeDetectEnable.field0 & 1, 0)
        XCTAssertEqual(registers.asyncFallingEdgeDetectEnable.field0 & 1, 0)
    }

    /// Test that .none is returned when both edge detect registers are 0.
    func testGetAsyncEdgeDetectNone() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        XCTAssertEqual(gpio[0].asyncEdgeDetect,  .none)
    }

    /// Test that we can set the edge detect registers to just rising.
    func testSetAsyncEdgeDetectRising() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure the right of the bits go to zero.
        registers.asyncFallingEdgeDetectEnable.field0 = ~0

        gpio[0].asyncEdgeDetect = .rising

        XCTAssertEqual(registers.asyncRisingEdgeDetectEnable.field0 & 1, 1)
        XCTAssertEqual(registers.asyncFallingEdgeDetectEnable.field0 & 1, 0)
    }

    /// Test that .rising is returned when the rising register is 1 and the falling is 0.
    func testGetAsyncEdgeDetectRising() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.asyncRisingEdgeDetectEnable.field0 = 1

        XCTAssertEqual(gpio[0].asyncEdgeDetect, .rising)
    }

    /// Test that we can set the edge detect registers to just falling.
    func testSetAsyncEdgeDetectFalling() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure the right of the bits go to zero.
        registers.asyncRisingEdgeDetectEnable.field0 = ~0

        gpio[0].asyncEdgeDetect = .falling

        XCTAssertEqual(registers.asyncRisingEdgeDetectEnable.field0 & 1, 0)
        XCTAssertEqual(registers.asyncFallingEdgeDetectEnable.field0 & 1, 1)
    }

    /// Test that .falling is returned when the falling register is 1 and the rising is 0.
    func testGetAsyncEdgeDetectFalling() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.asyncFallingEdgeDetectEnable.field0 = 1

        XCTAssertEqual(gpio[0].asyncEdgeDetect, .falling)
    }

    /// Test that we can set the edge detect registers to detect both 1.
    func testSetAsyncEdgeDetectBoth() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[0].asyncEdgeDetect = .both

        XCTAssertEqual(registers.asyncRisingEdgeDetectEnable.field0 & 1, 1)
        XCTAssertEqual(registers.asyncFallingEdgeDetectEnable.field0 & 1, 1)
    }

    /// Test that .both is returned when both edge detect registers are 0.
    func testGetAsyncEdgeDetectBoth() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.asyncRisingEdgeDetectEnable.field0 = 1
        registers.asyncFallingEdgeDetectEnable.field0 = 1

        XCTAssertEqual(gpio[0].asyncEdgeDetect, .both)
    }

    /// Test that we when we set a GPIO edge detect, it leaves the other bits alone.
    func testDiscreteAsyncEdgeDetect() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.asyncRisingEdgeDetectEnable.field0 = ~0
        registers.asyncRisingEdgeDetectEnable.field1 = ~0
        registers.asyncFallingEdgeDetectEnable.field0 = ~0
        registers.asyncFallingEdgeDetectEnable.field1 = ~0

        gpio[0].asyncEdgeDetect = .none

        XCTAssertEqual(registers.asyncRisingEdgeDetectEnable.field0 | 0b1, ~0)
        XCTAssertEqual(registers.asyncRisingEdgeDetectEnable.field1, ~0)
        XCTAssertEqual(registers.asyncFallingEdgeDetectEnable.field0 | 0b1, ~0)
        XCTAssertEqual(registers.asyncFallingEdgeDetectEnable.field1, ~0)
    }


    // MARK: Pull-up/down Enable.

    /// Test that we can set the pull-up/down register to disabled.
    func testPullUpDownDisable() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the bytes to make sure all of the bits go to zero.
        withUnsafeMutablePointer(to: &registers.pullUpDownEnable) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~1
            }
        }

        gpio.pullUpDownEnable = .disabled

        XCTAssertEqual(registers.pullUpDownEnable, 0b00)
    }

    /// Test that we can set the pull-up/down register to pull-down.
    func testPullDown() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio.pullUpDownEnable = .pullDown

        XCTAssertEqual(registers.pullUpDownEnable, 0b01)
    }

    /// Test that we can set the pull-up/down register to pull-down.
    func testPullUp() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio.pullUpDownEnable = .pullUp

        XCTAssertEqual(registers.pullUpDownEnable, 0b10)
    }

    /// Test that gets of the pull-up/down register always return `.disabled`.
    func testGetPullUpDown() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the bytes to make sure all of the bits go to zero.
        withUnsafeMutablePointer(to: &registers.pullUpDownEnable) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~1
            }
        }

        XCTAssertEqual(gpio.pullUpDownEnable, .disabled)
    }


    // MARK: Pull-up/down Clock Enable.

    /// Test that we can get the clock to enabled.
    func testSetPullUpDownClockEnabled() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        gpio[0].pullUpDownClock = true

        XCTAssertEqual(registers.pullUpDownEnableClock.field0 & 1, 1)
    }

    /// Test that we can get the clock to disabled.
    func testSetPullUpDownClockDisabled() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        // Corrupt the fields to make sure all of the bits go to zero.
        registers.pullUpDownEnableClock.field0 = ~0

        gpio[0].pullUpDownClock = false

        XCTAssertEqual(registers.pullUpDownEnableClock.field0 & 1, 0)
    }

    /// Test that we can get the current value of the clock.
    func testGetPullUpDownClock() {
        var registers = GPIO.Registers()
        let gpio = GPIO(registers: &registers)

        registers.pullUpDownEnableClock.field0 = 1

        XCTAssertEqual(gpio[0].pullUpDownClock, true)
    }

}

