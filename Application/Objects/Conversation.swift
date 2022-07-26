//
//  Conversation.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 07/03/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import UIKit

public class Conversation {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    //Arrays
    public var messages: [Message]!
    public var participantIdentifiers: [String]!
    
    //Other Declarations
    public var identifier: String!
    public var lastModifiedDate: Date!
    
    public var otherUser: User?
    
    //==================================================//
    
    /* MARK: - Constructor Function */
    
    public init(identifier: String,
                messages: [Message],
                lastModifiedDate: Date,
                participantIdentifiers: [String]) {
        self.identifier = identifier
        self.messages = messages
        self.lastModifiedDate = lastModifiedDate
        self.participantIdentifiers = participantIdentifiers
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    public func messageIdentifiers() -> [String]? {
        var identifierArray = [String]()
        
        for message in messages {
            identifierArray.append(message.identifier)
            
            if messages.count == identifierArray.count {
                return identifierArray
            }
        }
        
        return nil
    }
    
    ///Serializes the **Conversation's** metadata.
    public func serialize() -> [String: Any] {
        var data: [String: Any] = [:]
        
        data["identifier"] = identifier
        data["messages"] = messageIdentifiers() ?? ["!"] //failsafe. should NEVER return nil
        data["participants"] = participantIdentifiers
        data["lastModified"] = secondaryDateFormatter.string(from: lastModifiedDate)
        
        return data
    }
    
    public func setOtherUser(completion: @escaping(_ errorDescriptor: String?) -> Void) {
        let otherUserIdentifier = self.participantIdentifiers.filter({$0 != currentUserID})[0]
        
        UserSerializer.shared.getUser(withIdentifier: otherUserIdentifier) { (returnedUser,
                                                                              errorDescriptor) in
            if let user = returnedUser {
                self.otherUser = user
                completion(nil)
            } else {
                completion(errorDescriptor ?? "An unknown error occurred.")
            }
        }
    }
    
    public func sortedFilteredMessages() -> [Message] {
        var filteredMessages = [Message]()
        
        //Filters for duplicates and blank messages.
        for message in messages {
            if !filteredMessages.contains(where: { $0.identifier == message.identifier }) && message.identifier != "!" {
                filteredMessages.append(message)
            }
        }
        
        //Sorts by «sentDate».
        return filteredMessages.sorted(by: { $0.sentDate < $1.sentDate })
    }
}
