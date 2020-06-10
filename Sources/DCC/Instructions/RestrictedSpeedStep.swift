//
//  RestrictedSpeedStep.swift
//  DCC
//
//  Created by Scott James Remnant on 11/16/19.
//

import Foundation

public struct RestrictedSpeedStep : Packable {
    public var isRestricted: Bool

    @Clamping(0...28)
    public var speed: Int = 0

    public var direction: Direction?

    public init(isRestricted: Bool, speed: Int, direction: Direction? = nil) {
        self.isRestricted = isRestricted
        self.direction = direction
        self.speed = speed
    }

    public func add<T : Packer>(into packer: inout T) {
        // Advanced Operations.
        packer.add(0b001, length: 3)
        // Restricted Speed Step.
        packer.add(0b11110, length: 5)

        // It's not clear whether direction is meaningful, but include it since there is a bit
        // reserved for it.
        switch direction {
        case .forward?:
            packer.add(0b1, length: 1)
        case .reverse?:
            packer.add(0b0, length: 0)
        default:
            packer.add(0b0, length: 0)
        }

        // FIXME: I don't like that this is copied.
        if speed > 0 {
            let adjustedSpeed = speed + 3
            packer.add(adjustedSpeed, length: 1)
            packer.add(adjustedSpeed >> 1, length: 4)
        } else {
            packer.add(0b0, length: 1)
            packer.add(speed, length: 4)
        }
    }
}
