//
//  AnalogFunction.swift
//  DCC
//
//  Created by Scott James Remnant on 11/16/19.
//

import Foundation


public struct AnalogFunctionInstruction : Packable {
    public enum Output : Int {
        case volumeControl = 0b00000001
    }

    public var output: Output
    public var data: UInt8

    public init(output: Output, data: UInt8) {
        self.output = output
        self.data = data
    }

    public func add<T : Packer>(into packer: inout T) {
        // Advanced Operations.
        packer.add(0b001, length: 3)
        // Analog Function Group.
        packer.add(0b11101, length: 5)
        packer.add(output.rawValue, length: 8)
        packer.add(data)
    }

}
