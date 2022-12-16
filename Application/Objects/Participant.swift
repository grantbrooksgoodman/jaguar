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
    public var isTyping: Bool!
    
    //==================================================//
    
    /* MARK: - Constructor Function */
    
    public init(userID: String, isTyping: Bool) {
        self.userID = userID
        self.isTyping = isTyping
    }
    
    //==================================================//
    
    /* MARK: - Equatable Compliance Function */
    
    public static func == (left: Participant, right: Participant) -> Bool {
        let userIdsMatch = left.userID == right.userID
        let isTypingsMatch = left.isTyping == right.isTyping
        
        return userIdsMatch && isTypingsMatch
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: Array */
public extension Array where Element == Participant {
    var userIDs: [String] {
        var identifiers = [String]()
        
        for participant in self {
            identifiers.append(participant.userID)
        }
        
        return identifiers
    }
}

public extension Array where Element == String {
    var asParticipants: [Participant]? {
        var participants = [Participant]()
        
        for item in self {
            guard let asParticipant = item.asParticipant else {
                return nil
            }
            
            participants.append(asParticipant)
        }
        
        return participants
    }
}

/* MARK: String */
public extension String {
    var asParticipant: Participant? {
        let components = self.components(separatedBy: " | ")
        
        guard components.count > 1 else { return nil }
        
        let userID = components[0]
        let isTyping = components[1] == "true" ? true : false
        
        return Participant(userID: userID,
                           isTyping: isTyping)
    }
}


