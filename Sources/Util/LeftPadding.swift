//
//  LeftPadding.swift
//  SignalBox
//
//  Created by Scott James Remnant on 6/7/18.
//

public extension String {

    /// Returns a new string formed from by adding as many occurrences of `character` are necessary to the start to reach a length of `length`.
    public func leftPadding(toLength length: Int, withPad character: Character) -> String {
        return String(repeating: String(character), count: max(0, length - self.count)) + self
    }

}
