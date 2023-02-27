//
//  Message+ArrayExtensions.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 26/02/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public extension Array where Element == Message {
    
    // MARK: Properties
    
    var messageHashes: [String] {
        var hashArray = [String]()
        
        for message in self {
            hashArray.append(message.hash)
        }
        
        return hashArray
    }
    
    // MARK: Methods
    
    func unique() -> [Message] {
        var uniqueValues = [Message]()
        
        for message in self {
            if !uniqueValues.contains(where: { $0.identifier == message.identifier }) {
                uniqueValues.append(message)
            }
        }
        
        return uniqueValues
    }
}
