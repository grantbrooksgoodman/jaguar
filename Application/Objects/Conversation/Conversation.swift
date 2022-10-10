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
    
    /* MARK: - Properties */
    
    // Arrays
    public var messageIdentifiers: [String]!
    public var messages: [Message]! { didSet { messageIdentifiers = getMessageIdentifiers() } }
    public var participants: [Participant]!
    
    // Other
    public var identifier: ConversationID!
    public var lastModifiedDate: Date!
    public var otherUser: User?
    
    //==================================================//
    
    /* MARK: - Constructor Function */
    
    public init(identifier: ConversationID,
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
    
    /* MARK: - Enums */
    
    public enum Slice {
        case first
        case last
    }
    
    //==================================================//
    
    /* MARK: - Getter Functions */
    
    public func getMessageIdentifiers() -> [String] {
        var identifierArray = [String]()
        
        for message in messages {
            identifierArray.append(message.identifier)
            
            if messages.count == identifierArray.count {
                return identifierArray
            }
        }
        
        return identifierArray
    }
    
    public func sortedFilteredMessages(_ for: [Message]? = nil) -> [Message] {
        let messagesToUse = `for` == nil ? messages : `for`!
        
        var filteredMessages = [Message]()
        
        // Filters for duplicates and blank messages.
        for message in messagesToUse! {
            if !filteredMessages.contains(where: { $0.identifier == message.identifier }), message.identifier != "!" {
                filteredMessages.append(message)
            }
        }
        
        // Sorts by «sentDate».
        return filteredMessages.sorted(by: { $0.sentDate < $1.sentDate })
    }
    
    //==================================================//
    
    /* MARK: - Message Slicing Functions */
    
    public func get(_ slice: Slice,
                    messages count: Int,
                    offset: Int? = 0) -> [Message] {
        let offset = offset ?? 0
        
        print("wants to get last \(count) messages from conversation with \(messages.count) messages")
        print("wants to start at index \(offset)")
        print("messages[0...\(offset)] we have")
        print("messages[\(offset)...\(offset + count)] we want")
        print("messages[0...\(messages.count - 1)] are available")
        
        guard messages.count > offset else {
            Logger.log("Count of messages is less than offset + amount to get.",
                       metadata: [#file, #function, #line])
            return [] //getSlice(slice, messages: count)
        }
        
        let offsetMessages = slice == .first ? Array(messages[offset...messages.count - 1]) : Array(messages.reversed()[offset...messages.count - 1].reversed())
        
        var amountToGet = count
        
        guard offsetMessages.count > amountToGet else {
            while offsetMessages.count - 1 < amountToGet {
                amountToGet -= 1
            }
            
            print("Getting \(slice == .first ? "first" : "last") \(amountToGet + 1) messages.")
            return slice == .first ? Array(offsetMessages[0 ... amountToGet]) : Array(offsetMessages.reversed()[0 ... amountToGet].reversed())
        }
        
        print("Getting \(slice == .first ? "first" : "last") \(amountToGet + 1) messages!!")
        
        return slice == .first ? Array(offsetMessages[0 ... amountToGet]) : Array(offsetMessages.reversed()[0 ... amountToGet].reversed())
    }
    
    public func getHalf(_ slice: Slice) -> [Message] {
        switch slice {
        case .first:
            guard messages.count > 2 else {
                return [messages.first!]
            }
            
            return Array(messages[0 ... messages.count / 2])
        case .last:
            guard messages.count > 2 else {
                return [messages.last!]
            }
            
            return Array(messages[(messages.count / 2) + 1 ... messages.count - 1])
        }
    }
    
    //==================================================//
    
    /* MARK: - Serialization Functions */
    
    public func hashSerialized() -> [String] {
        var hashFactors = [String]()
        
        hashFactors.append(identifier.key)
        hashFactors.append(contentsOf: messageIdentifiers)
        
        return hashFactors
    }
    
    /// Serializes the **Conversation's** metadata.
    public func serialize() -> [String: Any] {
        var data: [String: Any] = [:]
        
        data["identifier"] = identifier
        data["messages"] = messageIdentifiers /* () */ ?? ["!"] // failsafe. should NEVER return nil
        data["lastModified"] = Core.secondaryDateFormatter!.string(from: lastModifiedDate)
        data["participants"] = serializedParticipants(from: participants)
        data["hash"] = hash
        
        return data
    }
    
    public func serializedParticipants(from: [Participant]) -> [String] {
        var participants = [String]()
        
        for participant in from {
            participants.append("\(participant.userID!) | \(participant.isTyping!)")
        }
        
        return participants
    }
    
    //==================================================//
    
    /* MARK: - Set/Update Functions */
    
    public func setOtherUser(completion: @escaping (_ errorDescriptor: String?) -> Void = { _ in }) {
        guard let otherUserIdentifier = participants.filter({ $0.userID != RuntimeStorage.currentUserID! })[0].userID else {
            completion("Couldn't find other user ID.")
            return
        }
        
        UserSerializer.shared.getUser(withIdentifier: otherUserIdentifier) { returnedUser,
            errorDescriptor in
            guard let user = returnedUser else {
                completion(errorDescriptor ?? "An unknown error occurred.")
                return
            }
            
            self.otherUser = user
            completion(nil)
        }
    }
    
    public func updateHash(completion: @escaping (_ errorDescriptor: String?) -> Void = { _ in }) {
        identifier.hash = hash
        
        GeneralSerializer.setValue(onKey: "/allConversations/\(identifier!.key!)/hash",
                                   withData: hash) { returnedError in
            guard returnedError == nil else {
                completion(Logger.errorInfo(returnedError!))
                return
            }
            
            let dispatchGroup = DispatchGroup()
            var errors = [String]()
            
            for participant in self.participants {
                dispatchGroup.enter()
                
                GeneralSerializer.getValues(atPath: "/allUsers/\(participant.userID!)/openConversations") { (returnedValues, errorDescriptor) in
                    guard var conversationIdentifiers = returnedValues as? [String] else {
                        errors.append(errorDescriptor ?? "An unknown error occurred.")
                        dispatchGroup.leave()
                        return
                    }
                    
                    conversationIdentifiers.removeAll(where: { $0.hasPrefix(self.identifier.key!) })
                    conversationIdentifiers.append("\(self.identifier!.key!) | \(self.hash)")
                    
                    GeneralSerializer.setValue(onKey: "/allUsers/\(participant.userID!)/openConversations",
                                               withData: conversationIdentifiers) { (returnedError) in
                        if let error = returnedError {
                            errors.append(Logger.errorInfo(error))
                        }
                        
                        dispatchGroup.leave()
                    }
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                let finalError = errors.joined(separator: "\n")
                completion(finalError == "" ? nil : finalError)
            }
        }
    }
    
    public func updateLastModified(completion: @escaping (_ errorDescriptor: String?) -> Void = { _ in }) {
        lastModifiedDate = Date()
        
        GeneralSerializer.setValue(onKey: "/allConversations/\(identifier!.key!)/lastModified",
                                   withData: Core.secondaryDateFormatter!.string(from: lastModifiedDate)) { returnedError in
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

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: Array */
public extension Array where Element == Conversation {
    func identifierKeys() -> [String] {
        var keys = [String]()
        
        for conversation in self {
            keys.append(conversation.identifier.key)
        }
        
        return keys
    }
    
    func unique() -> [Conversation] {
        var unique = [Conversation]()
        
        for conversation in self {
            if !unique.contains(where: { $0.identifier == conversation.identifier }) {
                unique.append(conversation)
            }
        }
        
        return unique
    }
}

/* MARK: Conversation */
public extension Conversation {
    var hash: String {
        do {
            let encoder = JSONEncoder()
            let encodedConversation = try! encoder.encode(self.hashSerialized())
            
            return encodedConversation.compressedHash
        }
    }
}
