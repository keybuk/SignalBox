//
//  ConfigurationVariableAccess.swift
//  DCC
//
//  Created by Scott James Remnant on 11/16/19.
//

import Foundation

public struct ConfigurationVariableAccessShort : Packable {
    public var variable: ConfigurationVariable
    public var data: UInt8

    public init(accelerationAdjustment data: UInt8) {
        self.variable = .accelerationAdjustment
        self.data = data
    }

    public init(decelerationAdjustment data: UInt8) {
        self.variable = .decelerationAdjustment
        self.data = data
    }

    public func add<T>(into packer: inout T) where T : Packer {
        // Configuration Variable Access - Short Form.
        packer.add(0b1111, length: 4)

        switch variable {
        case .accelerationAdjustment:
            packer.add(0b0010, length: 4)
        case .decelerationAdjustment:
            packer.add(0b0011, length: 4)
        // FIXME: 0b1001 see S-9.2.3 Appendix B
        default: preconditionFailure()
        }

        packer.add(data)
    }
}

public struct ConfigurationVariableAccess : Packable {
    public enum Operation {
        case verify
        case write
    }

    public var operation: Operation
    public var variable: ConfigurationVariable
    public var data: UInt8

    public init(variable: ConfigurationVariable, verify data: UInt8) {
        self.operation = .verify
        self.variable = variable
        self.data = data
    }

    public init(variable: ConfigurationVariable, write data: UInt8) {
        self.operation = .write
        self.variable = variable
        self.data = data
    }

    public func add<T>(into packer: inout T) where T : Packer {
        // Configuration Variable Access - Long Form.
        packer.add(0b1110, length: 4)

        switch operation {
        case .verify:
            packer.add(0b01, length: 2)
        case .write:
            packer.add(0b11, length: 2)
        }

        let adjustedValue = variable.rawValue - 1
        packer.add(adjustedValue, length: 10)

        packer.add(data)
    }

}

public struct ConfigurationVariableBitManipulation : Packable {
    public enum Operation {
        case verify
        case write
    }

    public var operation: Operation
    public var variable: ConfigurationVariable

    @Clamping(0...7)
    public var bit: Int = 0

    public var isSet: Bool

    public init(variable: ConfigurationVariable, bit: Int, verify isSet: Bool) {
        self.operation = .verify
        self.variable = variable
        self.isSet = isSet
        self.bit = bit
    }

    public init(variable: ConfigurationVariable, bit: Int, write isSet: Bool) {
        self.operation = .write
        self.variable = variable
        self.isSet = isSet
        self.bit = bit
    }

    public func add<T>(into packer: inout T) where T : Packer {
        // Configuration Variable Access - Long Form.
        packer.add(0b1110, length: 4)
        // Bit Manipulation.
        packer.add(0b10, length: 2)

        let adjustedValue = variable.rawValue - 1
        packer.add(adjustedValue, length: 10)

        packer.add(0b111, length: 3)

        switch operation {
        case .verify:
            packer.add(0b0, length: 1)
        case .write:
            packer.add(0b1, length: 1)
        }

        packer.add(isSet)

        packer.add(bit, length: 3)
    }
}
