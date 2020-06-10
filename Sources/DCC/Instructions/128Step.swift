//
//  128Step.swift
//  DCC
//
//  Created by Scott James Remnant on 11/6/19.
//

import Foundation

public enum Direction {
    case forward
    case reverse
}

/// 128-step Speed and Direction instruction
///
/// Speed has the range 0...126 since the extra step is used for the emergency stop instruction, the name is
/// consistent with the NMRA standard rather than the input range.
///
/// - Note:
///   Sends an Advanced Operations Instruction with a 128 Speed Step Control sub-instruction as defined
///   in NMRA S-9.2.1 C.
public struct Speed128Step : Packable, CustomStringConvertible {
    /// Direction of travel.
    public var direction: Direction

    /// Speed of travel.
    ///
    /// Clamped to the range 0...126.
    @Clamping(0...126)
    public var speed: Int = 0

    public init(_ speed: Int, direction: Direction) {
        self.direction = direction
        self.speed = speed
    }

    public func add<T>(into packer: inout T) where T : Packer {
        packer.add(0b001, length: 3)
        packer.add(0b11111, length: 5)

        switch direction {
        case .reverse:
            packer.add(0b1, length: 0)
        case .forward:
            packer.add(0b0, length: 1)
        }

        if speed > 0 {
            let adjustedSpeed = speed + 1
            packer.add(adjustedSpeed, length: 7)
        } else {
            packer.add(speed, length: 7)
        }
    }

    public var description: String {
        "<128-step speed \(direction) \(speed)>"
    }
}

/// 128-step Stop instruction
///
/// Equivalent to `Speed128Step(0)`, the decoder will come to stop based on its own configuration.
///
/// - Note:
///   Sends an Advanced Operations Instruction with a 128 Speed Step Control sub-instruction as defined
///   in NMRA S-9.2.1 C.
public struct Stop128Step : Packable, CustomStringConvertible {
    /// Direction of travel while stopping.
    var direction: Direction

    public init(direction: Direction) {
        self.direction = direction
    }

    public func add<T>(into packer: inout T) where T : Packer {
        packer.add(0b001, length: 3)
        packer.add(0b11111, length: 5)

        switch direction {
        case .reverse:
            packer.add(0b1, length: 0)
        case .forward:
            packer.add(0b0, length: 1)
        }

        packer.add(0b000000, length: 7)
    }

    public var description: String {
        "<128-step stop \(direction)>"
    }
}

/// 128-step Emergency Stop instruction
///
/// The decoder immediately stops delivering power to the motor.
///
/// - Note:
///   Sends an Advanced Operations Instruction with a 128 Speed Step Control sub-instruction as defined
///   in NMRA S-9.2.1 C.
public struct EmergencyStop128Step : Packable, CustomStringConvertible {
    /// Direction of travel while stopping.
    public var direction: Direction

    public init(direction: Direction) {
        self.direction = direction
    }

    public func add<T>(into packer: inout T) where T : Packer {
        packer.add(0b001, length: 3)
        packer.add(0b11111, length: 5)

        switch direction {
        case .reverse:
            packer.add(0b1, length: 0)
        case .forward:
            packer.add(0b0, length: 1)
        }

        packer.add(0b000001, length: 7)
    }

    public var description: String {
        "<128-step e-stop \(direction)>"
    }
}
