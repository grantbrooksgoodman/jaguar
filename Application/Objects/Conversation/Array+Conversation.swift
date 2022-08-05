//
//  Array+Conversation.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 04/08/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public extension Array where Element == Conversation {
    func identifiers() -> [String] {
        var identifiers = [String]()
        
        for conversation in self {
            identifiers.append(conversation.identifier)
        }
        
        return identifiers
    }
}
