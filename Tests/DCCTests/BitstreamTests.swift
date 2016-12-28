//
//  BitstreamTests.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/27/16.
//
//

import XCTest

@testable import DCC


class BitstreamTests: XCTestCase {
    
    static var allTests = {
       return [
            ("testPhysicalBit", testPhysicalBit),
        ]
    }()
    
    func testPhysicalBit() {
        var x = Bitstream(wordSize: 32)
        x.append(physicalBits: 0b1, count: 1)
        
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 1 << 31 , size: 1))
    }

    // physical bits
    
    // logical bit 1
    // logical bit 0
    
}
