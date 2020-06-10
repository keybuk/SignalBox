//
//  ConsistControl.swift
//  DCC
//
//  Created by Scott James Remnant on 11/16/19.
//

import Foundation

public struct ConsistControl : Packable {
    @Clamping(0...127)
    public var consistAddress: Int = 0

    public var direction: Direction

    public init(consistAddress: Int, direction: Direction = .forward) {
        self.direction = direction
        self.consistAddress = consistAddress
    }

    public func add<T : Packer>(into packer: inout T) {
        // Consist Control.
        packer.add(0b0001, length: 4)

        switch direction {
        case .forward:
            packer.add(0b0010, length: 4)
        case .reverse:
            packer.add(0b0011, length: 4)
        }

        packer.add(0b0, length: 1)
        packer.add(consistAddress, length: 7)
    }
}

