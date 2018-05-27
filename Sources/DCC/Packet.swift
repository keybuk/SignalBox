//
//  Packet.swift
//  DCC
//
//  Created by Scott James Remnant on 5/15/18.
//

import Foundation

public protocol Packet : Packable {
    
    var bytes: [UInt8] { get }

}

public extension Packet {
    
    public func add<T : Packer>(into packer: inout T) {
        let bytes = self.bytes
        for byte in bytes {
            packer.add(0, length: 1)
            packer.add(byte, length: 8)
        }
        
        let errorDetectionByte = bytes.reduce(0, { $0 ^ $1 })
        packer.add(0, length: 1)
        packer.add(errorDetectionByte, length: 8)
        
        packer.add(1, length: 1)
    }
    
}

public struct Preamble : Packable {
    
    // FIXME: This is just a thought experiment, it might not be the best way to do preambles.
    
    public var timing: PulseTiming
    public var withCutout: Bool
    
    init(timing: PulseTiming, withCutout: Bool = true) {
        self.timing = timing
        self.withCutout = withCutout
    }
    
    public func add<T : Packer>(into packer: inout T) {
        let count = withCutout ? timing.preambleCount : PulseTiming.preambleCountMin
        if count <= UInt64.bitWidth {
            // FIXME: since Packer iterates the bits anyway, is this really an optimisation?
            let bits: UInt64 = ~(~0 << count)
            packer.add(bits, length: count)
        } else {
            for _ in 0..<count {
                packer.add(1, length: 1)
            }
        }
    }
    
}
