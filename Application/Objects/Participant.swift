//
//  Participant.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 04/08/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public struct Participant: Codable {
    
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
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: Array */
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


