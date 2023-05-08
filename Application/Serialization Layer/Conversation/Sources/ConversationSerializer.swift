//
//  ConversationSerializer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 01/05/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import Firebase
import FirebaseDatabase

public struct ConversationSerializer {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public static let shared = ConversationSerializer()
    
    //==================================================//
    
    /* MARK: - Creation Methods */
    
    public func createConversation(initialMessageIdentifier: String,
                                   participants: [String],
                                   completion: @escaping(_ returnedConversation: Conversation?,
                                                         _ exception: Exception?) -> Void) {
        RuntimeStorage.currentUser?.updateLastActiveDate()
        
        var data: [String: Any] = [:]
        
        var serializedParticipants = [String]()
        for identifier in participants {
            serializedParticipants.append("\(identifier) | false | false")
        }
        
        let lastModifiedDate = Date()
        
        data["messages"] = [initialMessageIdentifier]
        data["lastModified"] = Core.secondaryDateFormatter!.string(from: lastModifiedDate)
        data["participants"] = serializedParticipants
        
        guard let deSerializedParticipants = serializedParticipants.asParticipants else {
            completion(nil, Exception("Couldn't deserialize participants.", metadata: [#file, #function, #line]))
            return
        }
        
        guard let generatedKey = Database.database().reference().child(GeneralSerializer.environment.shortString).child("/conversations/").childByAutoId().key else {
            completion(nil, Exception("Unable to generate key for new conversation.",
                                      metadata: [#file, #function, #line]))
            
            return
        }
        
        // #warning("Include call to getMessages() here.")
        let conversation = Conversation(identifier: ConversationID(key: generatedKey,
                                                                   hash: ""),
                                        messageIdentifiers: data["messages"] as! [String],
                                        messages: [],
                                        lastModifiedDate: lastModifiedDate,
                                        participants: deSerializedParticipants)
        
        let hash = conversation.hash
        data["hash"] = hash
        
        let pathPrefix = "/\(GeneralSerializer.environment.shortString)/conversations/"
        GeneralSerializer.updateChildValues(forKey: "\(pathPrefix)\(generatedKey)",
                                            with: data) { exception in
            if let exception {
                completion(nil, exception)
            } else {
                var finalErrorDescriptor = ""
                
                let dispatchGroup = DispatchGroup()
                
                for userID in participants {
                    dispatchGroup.enter()
                    
                    let pathPrefix = "/\(GeneralSerializer.environment.shortString)/users/"
                    GeneralSerializer.getValues(atPath: "\(pathPrefix)\(userID)/openConversations") { (returnedOpenConversations, exception) in
                        if let error = exception {
                            completion(nil, error)
                        } else {
                            guard var openConversations = returnedOpenConversations as? [String] else {
                                completion(nil, Exception("Couldn't deserialize open conversations.",
                                                          metadata: [#file, #function, #line]))
                                dispatchGroup.leave()
                                return
                            }
                            
                            openConversations.append("\(generatedKey) | \(hash)")
                            openConversations = openConversations.filter({ $0 != "!" })
                            
                            GeneralSerializer.updateChildValues(forKey: "\(pathPrefix)\(userID)",
                                                                with: ["openConversations": openConversations]) { exception in
                                if let exception {
                                    finalErrorDescriptor += "\(exception.descriptor!)\n"
                                }
                                
                                dispatchGroup.leave()
                            }
                        }
                    }
                }
                
                dispatchGroup.notify(queue: .main) {
                    completion(finalErrorDescriptor != "" ? nil : conversation,
                               finalErrorDescriptor == "" ? nil : Exception(finalErrorDescriptor.trimmingTrailingNewlines,
                                                                            metadata: [#file, #function, #line]))
                }
            }
        }
    }
    
    /// - Requires: `withUsers[0] == RuntimeStorage.currentUser`
    public func createConversation(between users: [User],
                                   completion: @escaping(_ conversation: Conversation?,
                                                         _ exception: Exception?) -> Void) {
        guard users.count == 2 else {
            completion(nil, Exception("Invalid number of users.",
                                      extraParams: ["Users.Count": users.count],
                                      metadata: [#file, #function, #line]))
            return
        }
        
        createConversation(initialMessageIdentifier: "!",
                           participants: [users[0].identifier,
                                          users[1].identifier]) { (returnedConversation, exception) in
            
            guard let conversation = returnedConversation else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            conversation.setOtherUser { (exception) in
                guard exception == nil else {
                    completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                guard users[0].openConversations == nil else {
                    users[0].openConversations!.append(conversation)
                    
                    // #warning("This should be here, right?")
                    ConversationArchiver.addToArchive(conversation)
                    completion(conversation, nil)
                    
                    return
                }
                
                users[0].deSerializeConversations { (returnedConversations,
                                                     exception) in
                    guard let updatedConversations = returnedConversations else {
                        completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                        return
                    }
                    
                    users[0].openConversations = updatedConversations
                    
                    ConversationArchiver.addToArchive(conversation)
                    
                    completion(conversation, nil)
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Deletion Methods */
    
    private func setConversationHidden(withIdentifier: String,
                                       newParticipants: [Participant],
                                       completion: @escaping(_ exception: Exception?) -> Void) {
        let pathPrefix = "/\(GeneralSerializer.environment.shortString)/conversations/"
        GeneralSerializer.setValue(newParticipants.serialized,
                                   forKey: "\(pathPrefix)\(withIdentifier)/participants") { exception in
            guard exception == nil else {
                completion(exception)
                return
            }
            
            ConversationSerializer.shared.getConversation(withIdentifier: withIdentifier) { conversation, exception in
                guard let conversation else {
                    completion(exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                conversation.participants = newParticipants
                conversation.updateHash { exception in
                    guard exception == nil else {
                        completion(exception!)
                        return
                    }
                    
                    ConversationArchiver.removeFromArchive(withKey: conversation.identifier.key)
                    completion(nil)
                }
            }
        }
    }
    
    public func deleteConversation(withIdentifier: String,
                                   completion: @escaping (_ exception: Exception?) -> Void = { _ in }) {
        let database = Database.database().reference()
        let pathPrefix = "/\(GeneralSerializer.environment.shortString)/conversations/"
        let conversationKey = "\(pathPrefix)\(withIdentifier)"
        
        database.child("\(conversationKey)/participants").observeSingleEvent(of: .value, with: { (returnedSnapshot) in
            guard let participantStrings = returnedSnapshot.value as? [String],
                  let participants = participantStrings.asParticipants else {
                completion(Exception("Unable to get participants from this conversation.",
                                     extraParams: ["ConversationID": withIdentifier],
                                     metadata: [#file, #function, #line]))
                return
            }
            
            // #warning("Bad for group chats.")
            guard participants.contains(where: { $0.hasDeleted }) else {
                var newParticipants = [Participant]()
                for participant in participants {
                    var newParticipant: Participant?
                    if participant.userID == RuntimeStorage.currentUserID {
                        newParticipant = Participant(userID: participant.userID,
                                                     hasDeleted: true,
                                                     isTyping: participant.isTyping)
                    }
                    
                    newParticipants.append(newParticipant ?? participant)
                }
                
                self.setConversationHidden(withIdentifier: withIdentifier,
                                           newParticipants: newParticipants) { exception in
                    guard exception == nil else {
                        completion(exception!)
                        return
                    }
                    
                    Logger.log("Set conversation hidden instead of deleted.",
                               metadata: [#file, #function, #line])
                    
                    completion(nil)
                }
                
                return
            }
            
            var exceptions = [Exception]()
            
            self.deleteConversation(withIdentifier: withIdentifier,
                                    forUsers: participants) { exception in
                if let exception {
                    exceptions.append(exception)
                }
                
                self.deleteMessages(fromConversation: withIdentifier) { exception in
                    if let exception {
                        exceptions.append(exception)
                    }
                    
                    GeneralSerializer.setValue(NSNull(),
                                               forKey: "\(conversationKey)/") { exception in
                        if let exception {
                            exceptions.append(exception)
                        }
                        
                        completion(exceptions.compiledException)
                    }
                }
            }
            
        }) { error in
            completion(Exception(error, metadata: [#file, #function, #line]))
        }
    }
    
    //==================================================//
    
    /* MARK: - Retrieval Methods */
    
    public func getConversation(withIdentifier: String,
                                completion: @escaping (_ conversation: Conversation?,
                                                       _ exception: Exception?) -> Void) {
        Database.database().reference().child(GeneralSerializer.environment.shortString).child("conversations").child(withIdentifier).observeSingleEvent(of: .value, with: { snapshot in
            guard let snapshot = snapshot.value as? NSDictionary,
                  var data = snapshot as? [String: Any] else {
                let exception = Exception("No conversation exists with the provided identifier.",
                                          extraParams: ["ConversationID": withIdentifier],
                                          metadata: [#file, #function, #line])
                
                completion(nil, exception)
                return
            }
            
            data["identifier"] = withIdentifier
            
            self.deSerializeConversation(fromData: data) { deSerializedConversation, exception in
                guard let conversation = deSerializedConversation else {
                    completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                completion(conversation, nil)
            }
        }) { (error) in
            completion(nil, Exception(error,
                                      metadata: [#file, #function, #line]))
        }
    }
    
    public func getConversations(withIdentifiers: [String],
                                 completion: @escaping(_ returnedConversations: [Conversation]?,
                                                       _ exception: Exception?) -> Void) {
        var conversations = [Conversation]()
        var exceptions = [Exception]()
        
        guard withIdentifiers != ["!"] else {
            completion(nil, Exception("No identifiers passed!", metadata: [#file, #function, #line]))
            return
        }
        
        guard !withIdentifiers.filter({ $0 != "!" }).isEmpty else {
            completion(nil, Exception("No identifiers passed!", metadata: [#file, #function, #line]))
            return
        }
        
        for identifier in withIdentifiers.filter({ $0 != "!" }) {
            getConversation(withIdentifier: identifier) { (returnedConversation,
                                                           exception) in
                if let conversation = returnedConversation {
                    conversations.append(conversation)
                } else {
                    exceptions.append(exception ?? Exception(metadata: [#file, #function, #line]))
                }
                
                if conversations.count + exceptions.count == withIdentifiers.count {
                    completion(conversations.isEmpty ? nil : conversations,
                               exceptions.compiledException)
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Updating Methods */
    
    public func updateConversation(_ conversation: Conversation,
                                   completion: @escaping (_ returnedConversation: Conversation?,
                                                          _ exception: Exception?) -> Void) {
        //Want to get messages from current conversation and update it with messages we don't have.
        let pathPrefix = "/\(GeneralSerializer.environment.shortString)/conversations/"
        Database.database().reference().child("\(pathPrefix)\(conversation.identifier.key!)").observeSingleEvent(of: .value, with: { (returnedSnapshot) in
            guard let snapshot = returnedSnapshot.value as? NSDictionary,
                  let data = snapshot as? [String: Any] else {
                completion(nil, Exception("Couldn't convert snapshot to data.", metadata: [#file, #function, #line]))
                return
            }
            
            guard let messageIdentifiers = data["messages"] as? [String]/*,
                                                                         let hash = data["hash"] as? String*/ else {
                completion(nil, Exception("Unable to retrieve the specified data.",
                                          extraParams: ["Data": data],
                                          metadata: [#file, #function, #line]))
                return
            }
            
            let updatedConversation = conversation
            let messagesToGet = messageIdentifiers.filter({ !updatedConversation.messageIdentifiers.contains($0) })
            
            guard messagesToGet.count > 0 else {
                updatedConversation.identifier.hash = updatedConversation.hash
                
                completion(updatedConversation, nil)
                return
            }
            
            MessageSerializer.shared.getMessages(withIdentifiers: messagesToGet) { (returnedMessages,
                                                                                    exception) in
                guard let messages = returnedMessages else {
                    completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                updatedConversation.messages.append(contentsOf: messages)
                updatedConversation.messages = updatedConversation.sortedFilteredMessages()
                
                completion(updatedConversation, nil)
            }
            
        }) { (error) in
            completion(nil, Exception(error,
                                      metadata: [#file, #function, #line]))
        }
    }
    
    public func updateConversations(_ conversations: [Conversation],
                                    completion: @escaping (_ returnedConversations: [Conversation]?,
                                                           _ exception: Exception?) -> Void) {
        let dispatchGroup = DispatchGroup()
        
        var exceptions = [Exception]()
        var updatedConversations = [Conversation]()
        
        for conversation in conversations {
            dispatchGroup.enter()
            
            self.updateConversation(conversation) { (returnedConversation,
                                                     exception) in
                guard let conversation = returnedConversation else {
                    exceptions.append(exception ?? Exception(metadata: [#file, #function, #line]))
                    
                    dispatchGroup.leave()
                    return
                }
                
                updatedConversations.append(conversation)
                dispatchGroup.leave()
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
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func deSerializeConversation(fromData: [String: Any],
                                         completion: @escaping(_ deSerializedConversation: Conversation?,
                                                               _ exception: Exception?) -> Void) {
        guard let identifier = fromData["identifier"] as? String else {
            completion(nil, Exception("Unable to deserialize «identifier».", metadata: [#file, #function, #line]))
            return
        }
        
        guard let messageIdentifiers = fromData["messages"] as? [String] else {
            completion(nil, Exception("Unable to deserialize «messages».", metadata: [#file, #function, #line]))
            return
        }
        
        guard let participants = fromData["participants"] as? [String],
              let deSerializedParticipants = participants.asParticipants else {
            completion(nil, Exception("Unable to deserialize «participants».", metadata: [#file, #function, #line]))
            return
        }
        
        guard let lastModifiedString = fromData["lastModified"] as? String else {
            completion(nil, Exception("Unable to deserialize «lastModifiedString».", metadata: [#file, #function, #line]))
            return
        }
        
        // #warning("Why does «secondaryDateFormatter» not work in testing, but this does?")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        formatter.locale = Locale(identifier: "en_GB")
        
        guard let lastModifiedDate = formatter.date(from: lastModifiedString) else {
            completion(nil, Exception("Unable to convert «lastModified» to Date.", metadata: [#file, #function, #line]))
            return
        }
        
        guard let hash = fromData["hash"] as? String else {
            completion(nil, Exception("Unable to deserialize «hash».", metadata: [#file, #function, #line]))
            return
        }
        
        let conversationID = ConversationID(key: identifier,
                                            hash: hash)
        
        MessageSerializer.shared.getMessages(withIdentifiers: messageIdentifiers) { (returnedMessages,
                                                                                     getMessagesStatus) in
            guard let messages = returnedMessages else {
                completion(nil, getMessagesStatus ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            let deSerializedConversation = Conversation(identifier: conversationID,
                                                        messageIdentifiers: messageIdentifiers,
                                                        messages: messages,
                                                        lastModifiedDate: lastModifiedDate,
                                                        participants: deSerializedParticipants)
            
            completion(deSerializedConversation, nil)
        }
    }
    
    private func deleteConversation(withIdentifier: String,
                                    forUsers: [Participant],
                                    completion: @escaping (_ exception: Exception?) -> Void) {
        let database = Database.database().reference()
        
        for (index, participant) in forUsers.enumerated() {
            let pathPrefix = "/\(GeneralSerializer.environment.shortString)/users/"
            let key = "\(pathPrefix)\(participant.userID!)/openConversations"
            
            database.child(key).observeSingleEvent(of: .value) { returnedSnapshot, error  in
                guard var conversationIdStrings = returnedSnapshot.value as? [String] else {
                    completion(Exception("Unable to get conversation IDs for this user.",
                                         extraParams: ["UserID": participant.userID!],
                                         metadata: [#file, #function, #line]))
                    return
                }
                
                conversationIdStrings.removeAll(where: { $0.hasPrefix(withIdentifier) })
                
                if conversationIdStrings.isEmpty {
                    conversationIdStrings = ["!"]
                }
                
                GeneralSerializer.setValue(conversationIdStrings,
                                           forKey: key) { exception in
                    guard let exception else {
                        // #warning("Pattern can lead to side effects.")
                        guard index == forUsers.count - 1 else { return }
                        completion(nil)
                        return
                    }
                    
                    completion(exception)
                }
            }
        }
    }
    
    private func deleteMessages(fromConversation withID: String,
                                completion: @escaping (_ exception: Exception?) -> Void) {
        let database = Database.database().reference()
        
        let pathPrefix = "/\(GeneralSerializer.environment.shortString)/conversations/"
        database.child("\(pathPrefix)\(withID)/messages").observeSingleEvent(of: .value, with: { (returnedSnapshot) in
            guard let messageIdentifiers = returnedSnapshot.value as? [String] else {
                completion(Exception("Unable to get participants from this conversation.",
                                     extraParams: ["ConversationID": withID],
                                     metadata: [#file, #function, #line]))
                return
            }
            
            var exceptions = [Exception]()
            for (index, identifier) in messageIdentifiers.enumerated() {
                AudioMessageSerializer.shared.deleteInputAudioComponent(forMessageWithId: identifier) { exception in
                    if let exception {
                        exceptions.append(exception)
                    }
                    
                    let pathPrefix = "/\(GeneralSerializer.environment.shortString)/messages/"
                    GeneralSerializer.setValue(NSNull(),
                                               forKey: "\(pathPrefix)\(identifier)") { exception in
                        if let exception {
                            exceptions.append(exception)
                        }
                        
                        if index == messageIdentifiers.count - 1 {
                            completion(exceptions.compiledException)
                        }
                    }
                }
            }
        })
    }
}
