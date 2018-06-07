//
//  LeftPaddingTests.swift
//  UtilTests
//
//  Created by Scott James Remnant on 6/7/18.
//

import XCTest

import Util

class LeftPaddingTests : XCTestCase {

    /// Make sure that String.leftPadding works as intended.
    func testLeftPadding() {
        let padded = "foo".leftPadding(toLength: 5, withPad: " ")
        XCTAssertEqual(padded, "  foo")
    }

    /// Make sure that String.leftPadding works when the length is already equal.
    func testLeftPaddingEqual() {
        let padded = "foo".leftPadding(toLength: 3, withPad: " ")
        XCTAssertEqual(padded, "foo")
    }

    /// Make sure that String.leftPadding works when the length is already greater.
    func testLeftPaddingGreater() {
        let padded = "foobar".leftPadding(toLength: 3, withPad: " ")
        XCTAssertEqual(padded, "foobar")
    }

}
