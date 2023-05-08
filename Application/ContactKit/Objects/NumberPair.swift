//
//  NumberPair.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 10/01/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public struct NumberPair: Codable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public var isMarkedCorrect: Bool // Have this perhaps for when you resolve a duplicate
    public var number: String!
    public var users: [User]!
    
    //==================================================//
    
    /* MARK: - Constructor */
    
    public init(number: String,
                users: [User],
                isMarkedCorrect: Bool? = nil) {
        self.number = number
        self.users = users
        self.isMarkedCorrect = isMarkedCorrect ?? false
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: Array */
public extension Array where Element == NumberPair {
    var users: [User] {
        var users = [User]()
        for pair in self {
            users.append(contentsOf: pair.users)
        }
        
        return users
    }
}
