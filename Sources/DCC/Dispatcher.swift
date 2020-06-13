//
//  Dispatcher.swift
//  DCC
//
//  Created by Scott James Remnant on 6/9/20.
//

import Foundation

public struct Dispatcher {
    /// Map of decoders being disptached.
    public var decoders: [Address: Decoder] = [:]

    public init() {
    }
}
