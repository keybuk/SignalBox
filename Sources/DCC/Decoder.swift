//
//  Decoder.swift
//  DCC
//
//  Created by Scott James Remnant on 6/9/20.
//

import Foundation

public struct Decoder {
    public let address: Address
    public var speed: Int

    public init(address: Address) {
        self.address = address
        self.speed = 0
    }

    public mutating func stop() {
        speed = 0
    }
}
