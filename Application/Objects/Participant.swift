//
//  Participant.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 04/08/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public class Participant: Codable {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    public var userID: String!
    public var isTyping: Bool!
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
    public init(userID: String, isTyping: Bool) {
        self.userID = userID
        self.isTyping = isTyping
    }
}
