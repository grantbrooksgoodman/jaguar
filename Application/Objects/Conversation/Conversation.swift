//
//  Conversation.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 07/03/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import UIKit

public class Conversation: Codable {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    //Arrays
    public var messageIdentifiers: [String]!
    public var messages: [Message]! {
        didSet {
            messageIdentifiers = getMessageIdentifiers()
        }
    }
    public var participants: [Participant]!
    
    //Other Declarations
    public var identifier: String!
    public var lastModifiedDate: Date!
    public var otherUser: User?
    
    //==================================================//
    
    /* MARK: - Constructor Function */
    
    public init(identifier: String,
                messageIdentifiers: [String],
                messages: [Message],
                lastModifiedDate: Date,
                participants: [Participant]) {
        self.identifier = identifier
        self.messageIdentifiers = messageIdentifiers
        self.messages = messages
        self.lastModifiedDate = lastModifiedDate
        self.participants = participants
    }
    
    //==================================================//
    
    /* MARK: - Enumerated Type Declarations */
    
    public enum Slice {
        case first
        case last
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    public func get(_ slice: Slice,
                    messages count: Int) -> [Message] {
        var amountToGet = count
        
        guard messages.count > amountToGet else {
            while messages.count - 1 < amountToGet {
                amountToGet -= 1
            }
            
            print("Getting \(slice == .first ? "first" : "last") \(amountToGet + 1) messages.")
            return slice == .first ? Array(messages[0...amountToGet]) : Array(messages.reversed()[0...amountToGet].reversed())
        }
        
        return slice == .first ? Array(messages[0...amountToGet]) : Array(messages.reversed()[0...amountToGet])
    }
    
    public func get(_ slice: Slice) -> [Message] {
        switch slice {
        case .first:
            guard messages.count > 2 else {
                return [messages.first!]
            }
            
            return Array(messages[0...messages.count / 2])
        case .last:
            guard messages.count > 2 else {
                return [messages.last!]
            }
            
            return Array(messages[(messages.count / 2) + 1...messages.count - 1])
        }
    }
    
    public func getMessageIdentifiers() -> [String]? {
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
        data["messages"] = messageIdentifiers/*()*/ ?? ["!"] //failsafe. should NEVER return nil
        data["participants"] = serializedParticipants(from: participants)
        data["lastModified"] = secondaryDateFormatter.string(from: lastModifiedDate)
        
        return data
    }
    
    public func serializedParticipants(from: [Participant]) -> [String] {
        var participants = [String]()
        
        for participant in from {
            participants.append("\(participant.userID!) | \(participant.isTyping!)")
        }
        
        return participants
    }
    
    #warning("Use this to speed up operations.")
    public func setMessages(completion: @escaping(_ errorDescriptor: String?) -> Void = { _ in } ) {
        MessageSerializer.shared.getMessages(withIdentifiers: messageIdentifiers) { (returnedMessages,
                                                                                     errorDescriptor) in
            guard let messages = returnedMessages else {
                let error = errorDescriptor ?? "An unknown error occurred."
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                completion(error)
                return
            }
            
            self.messages = messages
            completion(nil)
        }
    }
    
    public func setOtherUser(completion: @escaping(_ errorDescriptor: String?) -> Void = { _ in }) {
        guard let otherUserIdentifier = self.participants.filter({ $0.userID != currentUserID })[0].userID else {
            completion("Couldn't find other user ID.")
            return
        }
        
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
    
    public func sortedFilteredMessages(_ for: [Message]? = nil) -> [Message] {
        let messagesToUse = `for` == nil ? messages : `for`!
        
        var filteredMessages = [Message]()
        
        //Filters for duplicates and blank messages.
        for message in messagesToUse! {
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
