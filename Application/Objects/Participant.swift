//
//  Participant.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 04/08/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public struct Participant: Codable, Equatable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public var userID: String!
    public var hasDeleted: Bool!
    public var isTyping: Bool!
    
    //==================================================//
    
    /* MARK: - Constructor Method */
    
    public init(userID: String,
                hasDeleted: Bool,
                isTyping: Bool) {
        self.userID = userID
        self.hasDeleted = hasDeleted
        self.isTyping = isTyping
    }
    
    //==================================================//
    
    /* MARK: - Equatable Compliance Method */
    
    public static func == (left: Participant, right: Participant) -> Bool {
        let userIdsMatch = left.userID == right.userID
        let hasDeletedMatch = left.hasDeleted == right.hasDeleted
        let isTypingsMatch = left.isTyping == right.isTyping
        
        return userIdsMatch && hasDeletedMatch && isTypingsMatch
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: Array */
public extension Array where Element == Participant {
    var userIdPair: String {
        var compiledString = ""
        
        for (index, id) in userIDs.enumerated() {
            compiledString += index == 0 ? id : ", \(id)"
        }
        
        return compiledString
    }
    
    var userIDs: [String] {
        var identifiers = [String]()
        
        for participant in self {
            identifiers.append(participant.userID)
        }
        
        return identifiers
    }
    
    var serialized: [String] {
        var participants = [String]()
        
        for participant in self {
            participants.append("\(participant.userID!) | \(participant.hasDeleted!) | \(participant.isTyping!)")
        }
        
        return participants
    }
}

public extension Array where Element == String {
    var asParticipants: [Participant]? {
        var participants = [Participant]()
        
        for item in self {
            guard let asParticipant = item.asParticipant else { return nil }
            
            participants.append(asParticipant)
        }
        
        return participants
    }
}

/* MARK: String */
public extension String {
    var asParticipant: Participant? {
        let components = self.components(separatedBy: " | ")
        
        guard components.count == 3 else { return nil }
        
        let userID = components[0]
        let hasDeleted = components[1] == "true" ? true : false
        let isTyping = components[2] == "true" ? true : false
        
        return Participant(userID: userID,
                           hasDeleted: hasDeleted,
                           isTyping: isTyping)
    }
}


