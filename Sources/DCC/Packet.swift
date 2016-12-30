//
//  Packet.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/20/16.
//
//

public enum Direction {
    case forward
    case reverse
    case ignore
}

public struct Packet : Equatable {
    
    public let bytes: [Int]

    private init(bytes: [Int]) {
        self.bytes = bytes + [ bytes.reduce(0, { $0 ^ $1 }) ]
    }
    
    private static func multiFunction(address: Address, bytes: [Int]) -> Packet {
        var bytes = bytes
        switch address {
        case .broadcast:
            bytes.insert(0, at: 0)
        case .decoder(1...127):
            guard case let .decoder(decoderAddress) = address else { fatalError() }
            bytes.insert(decoderAddress, at: 0)
        case .decoder(127...9999):
            guard case let .decoder(decoderAddress) = address else { fatalError() }
            bytes.insert(contentsOf: [decoderAddress >> 8, decoderAddress & 0xff], at: 0)
        default:
            fatalError("address is outside valid range 1-9999")
        }
        return Packet(bytes: bytes)
    }

    public static let broadcastAddress: Int = 0
    
    /// Idle Packet for All Decoders.
    ///
    /// Perform no action, but consider the packet a valid DCC transmission addressed to a different decoder,
    ///
    /// - Note:
    ///   Defined by NMRA S-9.2.
    public static let idle = Packet(bytes: [0b11111111, 0b00000000])
    
    // MARK: Decoder and Consist Control
    
    public static func softReset(address: Address) -> Packet {
        return .multiFunction(address: address, bytes: [ 0b00000000 ])
    }
    
    public static func hardReset(address: Address) -> Packet {
        return .multiFunction(address: address, bytes: [ 0b00000001 ])
    }

    // MARK: Speed and Direction

    public static func speed28Step(address: Address, direction: Direction, speed: Int) -> Packet {
        assert(direction != .ignore, "direction may not be .ignore")
        assert(speed >= 1 && speed <= 28, "speed must be in range 1-28")
        
        var byte = 0b01 << 6
        byte |= direction == .forward ? 1 << 5 : 0
        byte |= (((speed + 3) & 0x1) << 4) | ((speed + 3) >> 1)
        
        return .multiFunction(address: address, bytes: [ byte ])
    }
    
    public static func stop28Step(address: Address, direction: Direction) -> Packet {
        var byte = 0b01 << 6
        byte |= direction == .forward ? 1 << 5 : 0
        byte |= direction == .ignore ? 1 << 4 : 0
        
        return .multiFunction(address: address, bytes: [ byte ])
    }
    
    public static func emergencyStop28Step(address: Address, direction: Direction) -> Packet {
        var byte = 0b01 << 6
        byte |= direction == .forward ? 1 << 5 : 0
        byte |= direction == .ignore ? 1 << 4 : 0
        byte |= 0b1
        
        return .multiFunction(address: address, bytes: [ byte ])
    }
    
    // MARK: Function Groups
    
    public static func function0To4(address: Address, headlight: Bool, f1: Bool, f2: Bool, f3: Bool, f4: Bool) -> Packet {
        var byte = 0b100 << 5
        byte |= headlight ? 1 << 4 : 0
        byte |= f1 ? 1 << 0 : 0
        byte |= f2 ? 1 << 1 : 0
        byte |= f3 ? 1 << 2 : 0
        byte |= f4 ? 1 << 3 : 0
        
        return .multiFunction(address: address, bytes: [ byte ])
    }
    
    public static func function5To8(address: Address, f5: Bool, f6: Bool, f7: Bool, f8: Bool) -> Packet {
        var byte = 0b1011 << 4
        byte |= f5 ? 1 << 0 : 0
        byte |= f6 ? 1 << 1 : 0
        byte |= f7 ? 1 << 2 : 0
        byte |= f8 ? 1 << 3 : 0
        
        return .multiFunction(address: address, bytes: [ byte ])
    }

    public static func function9To12(address: Address, f9: Bool, f10: Bool, f11: Bool, f12: Bool) -> Packet {
        var byte = 0b1010 << 4
        byte |= f9 ? 1 << 0 : 0
        byte |= f10 ? 1 << 1 : 0
        byte |= f11 ? 1 << 2 : 0
        byte |= f12 ? 1 << 3 : 0
        
        return .multiFunction(address: address, bytes: [ byte ])
    }
    

    
    public static func ==(lhs: Packet, rhs: Packet) -> Bool {
        return lhs.bytes == rhs.bytes
    }

}

public enum Address : ExpressibleByIntegerLiteral {
    
    case broadcast
    case decoder(address: Int)

    public init(integerLiteral value: IntegerLiteralType) {
        self = .decoder(address: value)
    }

}
