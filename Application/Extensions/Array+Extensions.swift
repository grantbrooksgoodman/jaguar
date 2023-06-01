//
//  Array+Extensions.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 31/05/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public extension Array where Element == ContactPair {
    var excludingCurrentUser: [ContactPair] {
        guard let currentUserID = RuntimeStorage.currentUserID else { return self }
        
        var filtered = [ContactPair]()
        
        for pair in self {
            guard let numberPairs = pair.numberPairs else {
                filtered.append(pair)
                continue
            }
            
            guard !numberPairs.contains(where: { $0.users.allSatisfy({ $0.identifier == currentUserID }) }) else { continue }
            
            filtered.append(pair)
        }
        
        return filtered
    }
}
