//
//  BinaryState.swift
//  DCC
//
//  Created by Scott James Remnant on 11/16/19.
//

import Foundation

public struct BinaryStateControl : Packable {
    @Clamping(0...32767)
    public var stateAddress: Int = 0

    public var isEnabled: Bool

    public init(setAllTo isEnabled: Bool) {
        self.isEnabled = isEnabled
        self.stateAddress = 0
    }

    public init(stateAddress: Int, isEnabled: Bool) {
        self.isEnabled = isEnabled
        self.stateAddress = stateAddress
    }

    public func add<T>(into packer: inout T) where T : Packer {
        // Feature Expansion.
        packer.add(0b110, length: 3)
        // Only send three-byte form when necessary: NMRA S-9.2.1 299-302.
        if stateAddress == 0 || stateAddress > 127 {
            // Binary State Control long form.
            packer.add(0b00000, length: 5)
            packer.add(isEnabled)
            // Low byte comes before high byte.
            packer.add(stateAddress, length: 7)
            packer.add(stateAddress >> 7, length: 8)
        } else {
            // Binary State Control short form.
            packer.add(0b11101, length: 5)
            packer.add(isEnabled)
            packer.add(stateAddress, length: 7)
        }
    }
}
