//
//  Dispatcher.swift
//  DCC
//
//  Created by Scott James Remnant on 6/9/20.
//

import Foundation

public struct Dispatcher {
    /// Map of decoders being disptached.
    public private(set) var decoders: [Address: Decoder] = [:]

    public init() {
    }

    /// Returns the current settings for the decoder with the address given.
    ///
    /// Changes to the returned `Decoder` do not take effect unless updated with
    /// `updateSettingsForDecoder(_:)`
    ///
    /// - Parameter address: address of decoder to return.
    /// - Returns: `Decoder` containing current settings or `nil` if no settings are present.
    public mutating func currentSettingsForDecoder(address: Address) -> Decoder? {
        decoders[address]
    }

    /// Update the settings for the given decoder.
    ///
    /// If `decoder` is not currently dispatched, dispatch will begin for it.
    ///
    /// - Parameter decoder: decoder to update settings for.
    public mutating func updateSettingsForDecoder(_ decoder: Decoder) {
        decoders[decoder.address] = decoder
    }

    /// Cease dispatch for the given decoder.
    /// - Parameter decoder: decoder to stop dispatching.
    public mutating func removeDecoder(_ decoder: Decoder) {
        decoders[decoder.address] = nil
    }
}
