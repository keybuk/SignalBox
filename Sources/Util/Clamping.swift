//
//  Clamping.swift
//  DCC
//
//  Created by Scott James Remnant on 11/4/19.
//

import Foundation

@propertyWrapper
public struct Clamping<Value : Comparable> {
    var value: Value
    let range: ClosedRange<Value>

    public init(wrappedValue value: Value, _ range: ClosedRange<Value>) {
        precondition(range.contains(value))
        self.value = value
        self.range = range
    }

    public var wrappedValue: Value {
        get { value }
        set { value = min(max(newValue, range.lowerBound), range.upperBound) }
    }
}
