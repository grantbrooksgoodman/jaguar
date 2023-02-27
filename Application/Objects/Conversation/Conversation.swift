//
//  Conversation.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 07/03/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import UIKit

public class Conversation: Codable, Equatable {
    
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
    
    /* MARK: - Constructor Method */
    
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
    
    /* MARK: - Getter Methods */
    
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
    
    /* MARK: - Message Slicing Methods */
    
    public func get(_ slice: Slice,
                    messages count: Int,
                    offset: Int? = 0) -> [Message] {
        let offset = offset ?? 0
        
        //        Logger.openStream(message: "Requesting \(slice == .first ? "first" : "last") *\(count)* messages from conversation with *\(messages.count)* messages.",
        //                          metadata: [#file, #function, #line])
        //        Logger.logToStream("Wants to start at index *\(offset).*", line: #line)
        //        Logger.logToStream("messages[0...\(offset)] we have.", line: #line)
        //        Logger.logToStream("Requesting messages[\(offset)...\(offset + count)].", line: #line)
        //        Logger.logToStream("messages[0...\(messages.count - 1) are available.", line: #line)
        
        guard messages.count > offset else {
            //            Logger.log("Count of messages is less than offset + amount to get.",
            //                       verbose: true,
            //                       metadata: [#file, #function, #line])
            return []
        }
        
        let offsetMessages = slice == .first ? Array(messages[offset...messages.count - 1]) : Array(messages.reversed()[offset...messages.count - 1].reversed())
        
        var amountToGet = count
        
        guard offsetMessages.count > amountToGet else {
            while offsetMessages.count - 1 < amountToGet {
                amountToGet -= 1
            }
            
            //            Logger.closeStream(message: "Getting \(slice == .first ? "first" : "last") *\(amountToGet + 1)* messages.",
            //                               onLine: #line)
            return slice == .first ? Array(offsetMessages[0 ... amountToGet]) : Array(offsetMessages.reversed()[0 ... amountToGet].reversed())
        }
        
        //        Logger.closeStream(message: "Getting \(slice == .first ? "first" : "last") *\(amountToGet + 1)* messages!!!",
        //                           onLine: #line)
        
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
    
    /* MARK: - Serialization Methods */
    
    public func hashSerialized() -> [String] {
        var hashFactors = [String]()
        
        hashFactors.append(identifier.key)
        hashFactors.append(contentsOf: messageIdentifiers)
        hashFactors.append(contentsOf: messages.messageHashes)
        hashFactors.append(contentsOf: participants.serialized)
        
        return hashFactors
    }
    
    /// Serializes the **Conversation's** metadata.
    public func serialize() -> [String: Any] {
        var data: [String: Any] = [:]
        
        data["identifier"] = identifier
        data["messages"] = messageIdentifiers /* () */ ?? ["!"] // failsafe. should NEVER return nil
        data["lastModified"] = Core.secondaryDateFormatter!.string(from: lastModifiedDate)
        data["participants"] = participants.serialized
        data["hash"] = hash
        
        return data
    }
    
    //==================================================//
    
    /* MARK: - Set/Update Methods */
    
    public func setOtherUser(completion: @escaping (_ exception: Exception?) -> Void = { _ in }) {
        guard let otherUserIdentifier = participants.filter({ $0.userID != RuntimeStorage.currentUserID! })[0].userID else {
            completion(Exception("Couldn't find other user ID.",
                                 metadata: [#file, #function, #line]))
            return
        }
        
        UserSerializer.shared.getUser(withIdentifier: otherUserIdentifier) { returnedUser,
            exception in
            guard let user = returnedUser else {
                completion(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            self.otherUser = user
            completion(nil)
        }
    }
    
    public func updateHash(completion: @escaping (_ exception: Exception?) -> Void = { _ in }) {
        identifier.hash = hash
        
        let pathPrefix = "/\(GeneralSerializer.environment.shortString)/conversations/"
        GeneralSerializer.setValue(onKey: "\(pathPrefix)\(identifier!.key!)/hash",
                                   withData: hash) { returnedError in
            guard returnedError == nil else {
                completion(Exception(returnedError!,
                                     metadata: [#file, #function, #line]))
                return
            }
            
            let dispatchGroup = DispatchGroup()
            var exceptions = [Exception]()
            
            for participant in self.participants {
                dispatchGroup.enter()
                
                let pathPrefix = "/\(GeneralSerializer.environment.shortString)/users/"
                GeneralSerializer.getValues(atPath: "\(pathPrefix)\(participant.userID!)/openConversations") { (returnedValues, exception) in
                    guard var conversationIdentifiers = returnedValues as? [String] else {
                        exceptions.append(exception ?? Exception(metadata: [#file, #function, #line]))
                        dispatchGroup.leave()
                        return
                    }
                    
                    conversationIdentifiers.removeAll(where: { $0.hasPrefix(self.identifier.key!) })
                    conversationIdentifiers.append("\(self.identifier!.key!) | \(self.hash)")
                    
                    GeneralSerializer.setValue(onKey: "\(pathPrefix)\(participant.userID!)/openConversations",
                                               withData: conversationIdentifiers) { (returnedError) in
                        if let error = returnedError {
                            exceptions.append(Exception(error, metadata: [#file, #function, #line]))
                        }
                        
                        dispatchGroup.leave()
                    }
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                completion(exceptions.compiledException)
            }
        }
    }
    
    public func updateLastModified(completion: @escaping (_ exception: Exception?) -> Void = { _ in }) {
        lastModifiedDate = Date()
        
        let pathPrefix = "/\(GeneralSerializer.environment.shortString)/conversations/"
        GeneralSerializer.setValue(onKey: "\(pathPrefix)\(identifier!.key!)/lastModified",
                                   withData: Core.secondaryDateFormatter!.string(from: lastModifiedDate)) { returnedError in
            guard returnedError == nil else {
                let error = Exception(returnedError!,
                                      metadata: [#file, #function, #line])
                
                Logger.log(error)
                completion(error)
                return
            }
            
            Logger.log("Updated last modified date.",
                       verbose: true,
                       metadata: [#file, #function, #line])
            completion(nil)
        }
    }
    
    //==================================================//
    
    /* MARK: - Equatable Compliance Method */
    
    public static func == (left: Conversation, right: Conversation) -> Bool {
        let identifiersMatch = left.identifier == right.identifier
        let messageIdsMatch = left.messageIdentifiers == right.messageIdentifiers
        let messagesMatch = left.messages == right.messages
        let lastModifiedDatesMatch = left.lastModifiedDate == right.lastModifiedDate
        let participantsMatch = left.participants == right.participants
        let otherUsersMatch = left.otherUser?.identifier == right.otherUser?.identifier
        
        return identifiersMatch && messageIdsMatch && messagesMatch && lastModifiedDatesMatch && participantsMatch && otherUsersMatch
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: Array */
public extension Array where Element == Conversation {
    /* MARK: - Methods */
    
    func hashes() -> [String] {
        var hashes = [String]()
        for conversation in self {
            hashes.append(conversation.hash)
        }
        return hashes
    }
    
    func matchesHashesOf(_ others: [Conversation]) -> Bool {
        guard count == others.count else { return false }
        
        var matches = [Conversation]()
        for conversation in self {
            for comparisonConversation in others {
                if conversation.hash == comparisonConversation.hash {
                    matches.append(conversation)
                }
            }
        }
        
        return matches.count == count
    }
    
    func identifiers() -> [ConversationID] {
        var identifiers = [ConversationID]()
        
        forEach { conversation in
            identifiers.append(conversation.identifier)
        }
        
        return identifiers
    }
    
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
            if !unique.contains(where: { $0 == conversation }) {
                unique.append(conversation)
            }
        }
        
        return unique
    }
    
    func uniquedByIdentifiers() -> [Conversation] {
        var unique = [Conversation]()
        
        for conversation in self {
            if !unique.contains(where: { $0.identifier == conversation.identifier }) {
                unique.append(conversation)
            }
        }
        
        return unique
    }
    
    //--------------------------------------------------//
    
    /* MARK: - Variables */
    
    var visibleForCurrentUser: [Conversation] {
        guard let currentUserID = RuntimeStorage.currentUserID else { return [] }
        
        var visible = [Conversation]()
        for conversation in self {
            guard let currentUserParticipant = conversation.participants.filter({ $0.userID == currentUserID }).first else { continue }
            
            if !currentUserParticipant.hasDeleted {
                visible.append(conversation)
            }
        }
        
        return visible
    }
}

/* MARK: Conversation */
public extension Conversation {
    /* MARK: - Methods */
    
    static func empty() -> Conversation {
        return Conversation(identifier: ConversationID(key: "EMPTY",
                                                       hash: "EMPTY"),
                            messageIdentifiers: [],
                            messages: [],
                            lastModifiedDate: Date(),
                            participants: [])
    }
    
    //--------------------------------------------------//
    
    /* MARK: - Variables */
    
    var hash: String {
        do {
            let encoder = JSONEncoder()
            let encodedConversation = try! encoder.encode(self.hashSerialized())
            
            return encodedConversation.compressedHash
        }
    }
}
