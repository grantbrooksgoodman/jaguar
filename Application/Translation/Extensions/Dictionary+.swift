//
//  Dictionary+.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 31/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public extension Dictionary where Key == String, Value == String {
    func hashEncoded() -> Dictionary {
        var newDictionary = [String: String]()
        
        for key in keys {
            newDictionary[key.compressedHash] = "\(key.alphaEncoded)–\(self[key]!.alphaEncoded)"
        }
        
        return newDictionary
    }
    
    func hashDecoded() -> Dictionary? {
        var newDictionary = [String: String]()
        
        for key in keys {
            guard let original = self[key]!.decoded(getInput: true),
                  let translated = self[key]!.decoded(getInput: false) else {
                return nil
            }
            
            newDictionary[original] = translated
        }
        
        return newDictionary
    }
}
