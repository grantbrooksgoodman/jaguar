//
//  User.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 07/03/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import UIKit

public class User: Codable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Arrays
    public var conversationIDs: [ConversationID]?
    public var openConversations: [Conversation]? {
        didSet {
            openConversations = openConversations?.uniquedByIdentifiers().visibleForCurrentUser.sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate })
            conversationIDs = openConversations?.identifiers()
        }
    }
    public var pushTokens: [String]?
    
    // Strings
    public var callingCode: String!
    public var identifier: String!
    public var languageCode: String!
    public var phoneNumber: String!
    public var region: String!
    
    // Other
    private(set) var isUpdatingConversations = false
    
    //==================================================//
    
    /* MARK: - Constructor */
    
    public init(identifier: String,
                callingCode: String,
                languageCode: String,
                conversationIDs: [ConversationID]?,
                phoneNumber: String,
                pushTokens: [String]?,
                region: String) {
        self.identifier = identifier
        self.callingCode = callingCode
        self.languageCode = languageCode
        self.conversationIDs = conversationIDs
        self.phoneNumber = phoneNumber
        self.pushTokens = pushTokens
        self.region = region
    }
    
    //==================================================//
    
    /* MARK: - Getter Methods */
    
    public func canStartConversation(with user: User,
                                     completion: @escaping(_ canStart: Bool,
                                                           _ exception: Exception?) -> Void) {
        guard user.identifier != identifier else {
            completion(false, Exception("Cannot start a conversation with yourself.",
                                        metadata: [#file, #function, #line]))
            return
        }
        
        deSerializeConversations(completion: { (returnedConversations,
                                                exception) in
            guard let conversations = returnedConversations else {
                completion(false, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            guard !conversations.contains(where: { $0.participants.contains(where: { $0.userID == user.identifier }) }) else {
                for conversation in conversations {
                    if conversation.participants.contains(where: { $0.userID == user.identifier }) {
                        if let selfParticipant = conversation.participants.first(where: { $0.userID == self.identifier }),
                           selfParticipant.hasDeleted {
                            completion(true, nil)
                            return
                        }
                    }
                }
                
                completion(false, Exception("Conversation with this user already exists.",
                                            isReportable: false,
                                            extraParams: ["UserID": user.identifier!,
                                                          "CellTitle": user.cellTitle],
                                            metadata: [#file, #function, #line]))
                return
            }
            
            completion(true, nil)
        })
    }
    
    public func deSerializeConversations(completion: @escaping (_ conversations: [Conversation]?,
                                                                _ exception: Exception?) -> Void) {
        let pathPrefix = "/\(GeneralSerializer.environment.shortString)/users/"
        GeneralSerializer.getValues(atPath: "\(pathPrefix)\(identifier!)/openConversations") { returnedIdentifiers, exception in
            guard let updatedIdentifiers = returnedIdentifiers as? [String] else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            guard updatedIdentifiers != ["!"] else {
                completion([], nil/*"No conversations to deserialize."*/)
                return
            }
            
            print("Conversations: \(updatedIdentifiers.count)")
            
            guard let asConversationIDs = updatedIdentifiers.asConversationIDs else {
                completion(nil, Exception("Unable to deserialize «openConversations».", metadata: [#file, #function, #line]))
                return
            }
            
            if asConversationIDs == self.conversationIDs,
               let openConversations = self.openConversations
            {
                completion(openConversations, nil)
            } else {
                let sorted = self.sortConversations(asConversationIDs)
                guard var conversationsToReturn = sorted[0] as? [Conversation],
                      let conversationsToUpdate = sorted[1] as? [Conversation],
                      let conversationsToFetch = sorted[2] as? [ConversationID] else {
                    completion(nil, Exception("Unable to sort conversations.",
                                              metadata: [#file, #function, #line]))
                    return
                }
                
                print("Conversations needing update: \(conversationsToUpdate.count)")
                print("Conversations needing fetch: \(conversationsToFetch.count)\(conversationsToFetch.count > 0 ? "\n" : "")")
                
                self.updateConversations(conversationsToUpdate) { (returnedConversations,
                                                                   exception) in
                    guard let updatedConversations = returnedConversations else {
                        completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                        return
                    }
                    
                    conversationsToReturn.append(contentsOf: updatedConversations)
                    
                    self.fetchConversations(conversationsToFetch) { (returnedConversations,
                                                                     exception) in
                        guard let fetchedConversations = returnedConversations else {
                            completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                            return
                        }
                        
                        conversationsToReturn.append(contentsOf: fetchedConversations)
                        
                        guard !conversationsToReturn.isEmpty else {
                            completion(nil, Exception("Conversations to return is still empty!",
                                                      metadata: [#file, #function, #line]))
                            return
                        }
                        
                        self.openConversations = conversationsToReturn
                        ConversationArchiver.addToArchive(conversationsToReturn)
                        completion(conversationsToReturn, nil)
                    }
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Setter Methods */
    
    public func update(isTyping: Bool,
                       inConversationWithID: String,
                       completion: @escaping (_ exception: Exception?) -> Void = { _ in }) {
        let pathPrefix = "/\(GeneralSerializer.environment.shortString)/conversations/"
        GeneralSerializer.getValues(atPath: "\(pathPrefix)\(inConversationWithID)") { returnedValues, exception in
            guard let values = returnedValues as? [String: Any] else {
                completion(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            guard let participants = values["participants"] as? [String],
                  let currentUserParticipant = participants.filter({ $0.components(separatedBy: " | ")[0] == self.identifier! }).first?.asParticipant else {
                completion(Exception("Couldn't deserialize participants.",
                                     metadata: [#file, #function, #line]))
                return
            }
            
            let otherUserID = participants.filter { $0.components(separatedBy: " | ")[0] != self.identifier! }.first!
            let updatedParticipants = ["\(self.identifier!) | \(currentUserParticipant.hasDeleted!) | \(isTyping)", otherUserID]
            
            let pathPrefix = "/\(GeneralSerializer.environment.shortString)/conversations/"
            GeneralSerializer.setValue(updatedParticipants,
                                       forKey: "\(pathPrefix)\(inConversationWithID)/participants") { exception in
                guard let exception else {
                    completion(nil)
                    return
                }
                
                completion(exception)
            }
        }
    }
    
    public func updatePushTokens(completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        guard let newToken = RuntimeStorage.pushToken else {
            completion(Exception("No stored push token.", metadata: [#file, #function, #line]))
            return
        }
        
        var pushTokens = pushTokens ?? []
        guard !pushTokens.contains(newToken) else {
            completion(Exception("Push token already stored on server!", metadata: [#file, #function, #line]))
            return
        }
        
        pushTokens.append(newToken)
        let pathPrefix = "/\(GeneralSerializer.environment.shortString)/users/"
        GeneralSerializer.setValue(pushTokens,
                                   forKey: "\(pathPrefix)\(identifier!)/pushTokens") { exception in
            guard exception == nil else {
                completion(exception!)
                return
            }
            
            completion(nil)
        }
    }
    
    public func updateLastActiveDate(completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        let pathPrefix = "/\(GeneralSerializer.environment.shortString)/users/"
        GeneralSerializer.setValue(Core.secondaryDateFormatter!.string(from: Date()),
                                   forKey: "\(pathPrefix)\(identifier!)/lastActive") { exception in
            completion(exception)
        }
    }
    
    //==================================================//
    
    /* MARK: - Push Notification Methods */
    
    public enum NotificationType { case textMessage(content: String); case audioMessage }
    public func notifyOfNewMessage(_ type: NotificationType,
                                   completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        switch type {
        case .textMessage(content: let content):
            notifyOfNewMessage(content) { exception in completion(exception) }
        case .audioMessage:
            notifyOfNewMessage() { exception in completion(exception) }
        }
    }
    
    private func notifyOfNewMessage(_ text: String? = nil,
                                    completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        guard let pushTokens else {
            completion(Exception("User hasn't registered for push notifications!", metadata: [#file, #function, #line]))
            return
        }
        
        let dispatchGroup = DispatchGroup()
        
        var exceptions = [Exception]()
        for token in pushTokens {
            dispatchGroup.enter()
            notify(for: token, text) { exception in
                if let exception {
                    exceptions.append(exception)
                }
                
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(exceptions.compiledException)
        }
    }
    
    private func notify(for pushToken: String,
                        _ text: String? = nil,
                        completion: @escaping(_ exception: Exception?) -> Void) {
        guard let url = URL(string: "https://fcm.googleapis.com/fcm/send") else {
            completion(Exception("Couldn't generate URL.", metadata: [#file, #function, #line]))
            return
        }
        
        guard let apiKey = MetadataService.pushApiKey else {
            completion(Exception("Couldn't get push API key.", metadata: [#file, #function, #line]))
            return
        }
        
        guard let currentUser = RuntimeStorage.currentUser else {
            completion(Exception("Couldn't get current user.", metadata: [#file, #function, #line]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("key=\(apiKey)", forHTTPHeaderField: "Authorization")
        
        var payload: [String: Any] = ["to": pushToken,
                                      "mutable_content": true]
        payload["notification"] = ["title": currentUser.compiledPhoneNumber.phoneNumberFormatted,
                                   "body": text ?? "AUDIO",
                                   "badge": badgeNumber]
        payload["data"] = ["isAudioMessage": text == nil,
                           "userHash": currentUser.phoneNumber.digits.compressedHash]
        
        do {
            try request.httpBody = JSONSerialization.data(withJSONObject: payload)
        } catch let error {
            completion(Exception(error, metadata: [#file, #function, #line]))
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                completion(Exception(error!, metadata: [#file, #function, #line]))
                return
            }
            
            guard let httpStatus = response as? HTTPURLResponse else {
                completion(Exception("Couldn't get response as HTTP URL response.",
                                     metadata: [#file, #function, #line]))
                return
            }
            
            guard httpStatus.statusCode == 200 else {
                completion(Exception("Should have status code 200.",
                                     extraParams: ["StatusCode": httpStatus.statusCode],
                                     metadata: [#file, #function, #line]))
                return
            }
            
            guard let data else {
                completion(Exception("Couldn't get data from HTTP response.",
                                     metadata: [#file, #function, #line]))
                return
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                guard responseString.contains("\"success\":1") else {
                    completion(Exception("Response data did not indicate success.",
                                         extraParams: ["ResponseString": responseString],
                                         metadata: [#file, #function, #line]))
                    return
                }
                
                completion(nil)
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func fetchConversations(_ identifiers: [ConversationID],
                                    completion: @escaping (_ returnedConversations: [Conversation]?,
                                                           _ exception: Exception?) -> Void) {
        
        guard identifiers.count > 0 else {
            completion([], nil)
            return
        }
        
        ConversationSerializer.shared.getConversations(withIdentifiers: identifiers.keys) { (returnedConversations,
                                                                                             exception) in
            guard let fetchedConversations = returnedConversations else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            let dispatchGroup = DispatchGroup()
            var exceptions = [Exception]()
            
            for conversation in fetchedConversations {
                dispatchGroup.enter()
                
                conversation.setOtherUser { (exception) in
                    if let error = exception {
                        exceptions.append(error)
                    }
                    
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                if fetchedConversations.count + exceptions.count == identifiers.count {
                    completion(fetchedConversations.isEmpty ? nil : fetchedConversations,
                               exceptions.compiledException)
                } else {
                    let failedToGet = identifiers.keys.filter({ !fetchedConversations.identifierKeys().contains($0) })
                    let mismatchedException = Exception("Mismatched conversation input/output.",
                                                        extraParams: ["FailedToGet": failedToGet],
                                                        metadata: [#file, #function, #line])
                    
                    let finalException = exception == nil ? mismatchedException : exception!.appending(underlyingException: mismatchedException)
                    
                    completion(nil, finalException)
                }
            }
        }
    }
    
    private func sortConversations(_ identifiers: [ConversationID]) -> [[Any]] {
        var conversationsToReturn = [Conversation]()
        var conversationsToUpdate = [Conversation]()
        var conversationsToFetch = [ConversationID]()
        
        for identifier in identifiers {
            let keyPrefix = identifier.key!.characterArray[0...4].joined()
            let hashPrefix = identifier.hash!.characterArray[0...3].joined()
            
            print("\nSearching archive for \(keyPrefix) | \(hashPrefix)")
            
            if let conversation = ConversationArchiver.getFromArchive(identifier) {
                print("Found \(keyPrefix) | \(hashPrefix) already in archive! – Up to date.\n")
                conversationsToReturn.append(conversation)
            } else {
                if let archivedConversation = ConversationArchiver.getFromArchive(withKey: identifier.key) {
                    print("Found \(keyPrefix) in archive, but needs update.\n")
                    conversationsToUpdate.append(archivedConversation)
                } else {
                    print("Didn't find \(keyPrefix) | \(hashPrefix) in archive.\n")
                    conversationsToFetch.append(identifier)
                }
            }
        }
        
        return [conversationsToReturn, conversationsToUpdate, conversationsToFetch]
    }
    
    //NOT MUTUALLY EXCLUSIVE RETURN.
    private func updateConversations(_ conversations: [Conversation],
                                     completion: @escaping (_ returnedConversations: [Conversation]?,
                                                            _ exception: Exception?) -> Void) {
        guard conversations.count > 0 else {
            completion([], nil)
            return
        }
        
        ConversationSerializer.shared.updateConversations(conversations) { (returnedConversations,
                                                                            exception) in
            guard let updatedConversations = returnedConversations else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            let dispatchGroup = DispatchGroup()
            var exceptions = [Exception]()
            
            for conversation in updatedConversations {
                dispatchGroup.enter()
                
                if conversation.otherUser != nil {
                    dispatchGroup.leave()
                } else {
                    conversation.setOtherUser { (exception) in
                        if let error = exception {
                            exceptions.append(error)
                        }
                        
                        dispatchGroup.leave()
                    }
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                if updatedConversations.count + exceptions.count == conversations.count {
                    completion(updatedConversations.isEmpty ? nil : updatedConversations,
                               exceptions.compiledException)
                } else {
                    let failedToGet = conversations.identifierKeys().filter({ !updatedConversations.identifierKeys().contains($0) })
                    completion(nil, Exception("Mismatched conversation input/output.",
                                              extraParams: ["FailedToGet": failedToGet],
                                              metadata: [#file, #function, #line]))
                }
            }
        }
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: Array */
public extension Array where Element == User {
    func callingCodes() -> [String] {
        var callingCodes = [String]()
        
        for user in self {
            callingCodes.append(user.callingCode)
        }
        
        return callingCodes
    }
    
    func identifiers() -> [String] {
        var identifiers = [String]()
        
        for user in self {
            identifiers.append(user.identifier)
        }
        
        return identifiers
    }
    
    func rawPhoneNumbers() -> [String] {
        var phoneNumbers = [String]()
        
        for user in self {
            phoneNumbers.append(user.phoneNumber)
        }
        
        return phoneNumbers
    }
    
    func uniquedByIdentifiers() -> [User] {
        var unique = [User]()
        
        for user in self {
            if !unique.contains(where: { $0.identifier == user.identifier }) {
                unique.append(user)
            }
        }
        
        return unique
    }
}

/* MARK: Sequence */
public extension Sequence where Iterator.Element == String {
    func containsAny(in array: [String]) -> Bool {
        for individualString in array {
            if contains(individualString) {
                return true
            }
        }
        
        return false
    }
    
    func lowercasedElements() -> [String] {
        var finalArray: [String]! = []
        
        for individualString in self {
            finalArray.append(individualString.lowercased())
        }
        
        return finalArray
    }
    
    func removingSpecialCharacters() -> [String] {
        let acceptableCharacters = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890")
        
        var finalArray: [String]! = []
        
        for individualString in self {
            finalArray.append(individualString.filter { acceptableCharacters.contains($0) })
        }
        
        return finalArray
    }
}

/* MARK: User */
public extension User {
    var compiledPhoneNumber: String {
        return "\(callingCode!)\(phoneNumber!)"
    }
    
    var badgeNumber: Int {
        var badgeNumber = 0
        
        guard let openConversations,
              !openConversations.isEmpty else { return 0 }
        
        func incrementForUnread(_ messages: [Message]) {
            for message in messages where message.readDate == nil {
                badgeNumber += 1
            }
        }
        
        for conversation in openConversations {
            guard let lastFromCurrentUser = conversation.messages.last(where: { $0.fromAccountIdentifier == identifier }),
                  let indexOfLast = conversation.messages.firstIndex(of: lastFromCurrentUser) else {
                incrementForUnread(conversation.messages)
                continue
            }
            
            guard conversation.messages.count > indexOfLast else { continue }
            
            let slice = conversation.messages[indexOfLast...conversation.messages.count - 1]
            guard slice.count > 1 else { continue }
            
            let filteredSlice = slice.filter({ $0.fromAccountIdentifier != identifier })
            guard filteredSlice.count > 0 else { continue }
            incrementForUnread(filteredSlice)
        }
        
        return badgeNumber
    }
    
    var cellTitle: String {
        guard let archivedPair = ContactArchiver.getFromArchive(withUserHash: phoneNumber.compressedHash),
              archivedPair.contact.firstName.lowercasedTrimmingWhitespace != "" else {
            return "\(callingCode!)\(phoneNumber!)".phoneNumberFormatted
        }
        
        return "\(archivedPair.contact.firstName) \(archivedPair.contact.lastName)"
    }
}
