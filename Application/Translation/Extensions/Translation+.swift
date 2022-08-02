//
//  Translation+.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 31/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import Translator

public extension Translation {
    func serialize() -> (key: String, value: String) {
        let value = input.value()
        
        return ("\(value.compressedHash)", "\(value.alphaEncoded)–\(output.matchingCapitalization(of: value).alphaEncoded)")
    }
}
