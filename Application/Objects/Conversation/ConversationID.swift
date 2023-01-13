//
//  ConversationID.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 25/08/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public struct ConversationID: Codable, Equatable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Strings
    public var hash: String!
    public var key: String!
    
    //==================================================//
    
    /* MARK: - Constructor Method */
    
    public init(key: String, hash: String) {
        self.key = key
        self.hash = hash
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: Array */
public extension Array where Element == ConversationID {
    var keys: [String] {
        var keyArray = [String]()
        
        for item in self {
            keyArray.append(item.key)
        }
        
        return keyArray
    }
}

public extension Array where Element == String {
    var asConversationIDs: [ConversationID]? {
        var conversationIDs = [ConversationID]()
        
        for item in self {
            guard let asConversationID = item.asConversationID else { return nil }
            
            conversationIDs.append(asConversationID)
        }
        
        return conversationIDs
    }
}

/* MARK: ConversationID */
public extension ConversationID {
    static func == (left: ConversationID, right: ConversationID) -> Bool {
        if left.hash == right.hash,
           left.key == right.key {
            return true
        }
        
        return false
    }
}

/* MARK: String */
public extension String {
    var asConversationID: ConversationID? {
        let components = self.components(separatedBy: " | ")
        
        guard components.count > 1 else { return nil }
        
        return ConversationID(key: components[0],
                              hash: components[1])
    }
}
