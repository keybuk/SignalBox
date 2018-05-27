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
