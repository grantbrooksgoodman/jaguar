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
    public var participantIdentifiers: [(id: String, typing: Bool)]!
    
    //Other Declarations
    public var identifier: String!
    public var lastModifiedDate: Date!
    
    public var otherUser: User?
    
    //==================================================//
    
    /* MARK: - Constructor Function */
    
    public init(identifier: String,
                messages: [Message],
                lastModifiedDate: Date,
                participantIdentifiers: [(id: String, typing: Bool)]) {
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
        data["participants"] = serializedParticipants(from: participantIdentifiers)
        data["lastModified"] = secondaryDateFormatter.string(from: lastModifiedDate)
        
        return data
    }
    
    public func serializedParticipants(from: [(id: String, typing: Bool)]) -> [String] {
        var participants = [String]()
        
        for participant in from {
            participants.append("\(participant.id) | \(participant.typing)")
        }
        
        return participants
    }
    
    public func setOtherUser(completion: @escaping(_ errorDescriptor: String?) -> Void) {
        let otherUserIdentifier = self.participantIdentifiers.filter({ $0.id != currentUserID })[0].id
        
        UserSerializer.shared.getUser(withIdentifier: otherUserIdentifier) { (returnedUser,
                                                                              errorDescriptor) in
            guard let user = returnedUser else {
                completion(errorDescriptor ?? "An unknown error occurred.")
                return
            }
            
            self.otherUser = user
            completion(nil)
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
    
    public func updateLastModified(completion: @escaping (_ errorDescriptor: String?) -> Void = { _ in }) {
        GeneralSerializer.setValue(onKey: "/allConversations/\(identifier!)/lastModified",
                                   withData: secondaryDateFormatter.string(from: Date())) { (returnedError) in
            guard returnedError == nil else {
                let error = Logger.errorInfo(returnedError!)
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                completion(error)
                return
            }
            
            Logger.log("Updated last modified date.",
                       verbose: true,
                       metadata: [#file, #function, #line])
            completion(nil)
        }
    }
}
