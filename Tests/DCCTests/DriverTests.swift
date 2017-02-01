//
//  DriverTests.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/30/16.
//
//

import XCTest

@testable import RaspberryPi
@testable import DCC


class DriverTests : XCTestCase {

    var raspberryPi: RaspberryPi!
    
    override func setUp() {
        super.setUp()
        
        raspberryPi = RaspberryPi(peripheralAddress: 0x3f000000, peripheralSize: 0x01000000)
    }

    func testSomething() {
    }

}

extension DriverTests {
    
    static var allTests = {
        return [
            ("testSomething", testSomething),
        ]
    }()

}
