//
//  LeftPadding.swift
//  Util
//
//  Created by Scott James Remnant on 6/7/18.
//

extension String {
    /// Returns a new string formed from by adding as many occurrences of `character` are necessary to the start to reach a length of `length`.
    public func leftPadding(toLength length: Int, with character: Character) -> String {
        String(repeating: String(character), count: max(0, length - self.count)) + self
    }
}
