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
    
    /* MARK: - Creation Functions */
    
    public func createConversation(initialMessageIdentifier: String,
                                   participants: [String],
                                   completion: @escaping(_ returnedConversation: Conversation?,
                                                         _ errorDescriptor: String?) -> Void) {
        RuntimeStorage.currentUser?.updateLastActiveDate()
        
        var data: [String: Any] = [:]
        
        var serializedParticipants = [String]()
        
        for identifier in participants {
            serializedParticipants.append("\(identifier) | false")
        }
        
        let lastModifiedDate = Date()
        
        data["messages"] = [initialMessageIdentifier]
        data["lastModified"] = Core.secondaryDateFormatter!.string(from: lastModifiedDate)
        data["participants"] = serializedParticipants
        
        guard let deSerializedParticipants = serializedParticipants.asParticipants else {
            completion(nil, "Couldn't deserialize participants.")
            return
        }
        
        guard let generatedKey = Database.database().reference().child("/allConversations/").childByAutoId().key else {
            Logger.log("Unable to generate key for new conversation.",
                       metadata: [#file, #function, #line])
            
            completion(nil, "Unable to generate key for new conversation.")
            return
        }
        
        let conversation = Conversation(identifier: ConversationID(key: generatedKey,
                                                                   hash: ""),
                                        messageIdentifiers: ["!"],
                                        messages: [],
                                        lastModifiedDate: lastModifiedDate,
                                        participants: deSerializedParticipants)
        
        let hash = conversation.hash
        data["hash"] = hash
        
        GeneralSerializer.updateValue(onKey: "/allConversations/\(generatedKey)",
                                      withData: data) { (returnedError) in
            if let error = returnedError {
                completion(nil, Logger.errorInfo(error))
            } else {
                var finalErrorDescriptor = ""
                
                let dispatchGroup = DispatchGroup()
                
                for userID in participants {
                    dispatchGroup.enter()
                    
                    GeneralSerializer.getValues(atPath: "/allUsers/\(userID)/openConversations") { (returnedOpenConversations, errorDescriptor) in
                        if let error = errorDescriptor {
                            completion(nil, error)
                        } else {
                            guard var openConversations = returnedOpenConversations as? [String] else {
                                completion(nil, "Couldn't deserialize open conversations.")
                                dispatchGroup.leave()
                                return
                            }
                            
                            openConversations.append("\(generatedKey) | \(hash)")
                            openConversations = openConversations.filter({ $0 != "!" })
                            
                            GeneralSerializer.updateValue(onKey: "/allUsers/\(userID)",
                                                          withData: ["openConversations": openConversations]) { (returnedError) in
                                if let error = returnedError {
                                    finalErrorDescriptor += "\(error)\n"
                                }
                                
                                dispatchGroup.leave()
                            }
                        }
                    }
                }
                
                dispatchGroup.notify(queue: .main) {
                    completion(finalErrorDescriptor != "" ? nil : conversation,
                               finalErrorDescriptor == "" ? nil : finalErrorDescriptor.trimmingTrailingNewlines)
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Deletion Functions */
    
    public func deleteConversation(withIdentifier: String,
                                   completion: @escaping (_ errorDescriptor: String?) -> Void = { _ in }) {
        let database = Database.database().reference()
        let conversationKey = "/allConversations/\(withIdentifier)"
        
        database.child("\(conversationKey)/participants").observeSingleEvent(of: .value, with: { (returnedSnapshot) in
            guard let participantStrings = returnedSnapshot.value as? [String],
                  let participants = participantStrings.asParticipants else {
                completion("Unable to get participants from this conversation.")
                return
            }
            
            self.deleteConversation(withIdentifier: withIdentifier,
                                    forUsers: participants) { (errorDescriptor) in
                if let error = errorDescriptor {
                    completion(error)
                }
                
                self.deleteMessages(fromConversation: withIdentifier) { (errorDescriptor) in
                    if let error = errorDescriptor {
                        completion(error)
                    }
                    
                    GeneralSerializer.setValue(onKey: "\(conversationKey)/",
                                               withData: NSNull()) { (returnedError) in
                        if let error = returnedError {
                            completion(Logger.errorInfo(error))
                        }
                        
                        completion(nil)
                    }
                }
            }
            
        }) { (error) in
            completion("Unable to retrieve the specified data. (\(Logger.errorInfo(error)))")
        }
    }
    
    //==================================================//
    
    /* MARK: - Retrieval Functions */
    
    public func getConversation(withIdentifier: String,
                                completion: @escaping (_ returnedConversation: Conversation?,
                                                       _ errorDescriptor: String?) -> Void) {
        Database.database().reference().child("allConversations").child(withIdentifier).observeSingleEvent(of: .value, with: { (returnedSnapshot) in
            guard let snapshot = returnedSnapshot.value as? NSDictionary,
                  var data = snapshot as? [String: Any] else {
                completion(nil, "No conversation exists with the identifier \"\(withIdentifier)\".")
                return
            }
            
            data["identifier"] = withIdentifier
            
            self.deSerializeConversation(fromData: data) { (returnedConversation,
                                                            errorDescriptor) in
                guard let conversation = returnedConversation else {
                    completion(nil, errorDescriptor ?? "An unknown error occurred.")
                    return
                }
                
                completion(conversation, nil)
            }
        }) { (error) in
            completion(nil, "Unable to retrieve the specified data. (\(Logger.errorInfo(error)))")
        }
    }
    
    public func getConversations(withIdentifiers: [String],
                                 completion: @escaping(_ returnedConversations: [Conversation]?,
                                                       _ errorDescriptor: String?) -> Void) {
        var conversations = [Conversation]()
        var errorDescriptors = [String]()
        
        guard withIdentifiers != ["!"] else {
            return
        }
        
        guard !withIdentifiers.filter({ $0 != "!" }).isEmpty else {
            completion(nil, "No identifiers passed!")
            return
        }
        
        for identifier in withIdentifiers.filter({ $0 != "!" }) {
            getConversation(withIdentifier: identifier) { (returnedConversation,
                                                           errorDescriptor) in
                if let conversation = returnedConversation {
                    conversations.append(conversation)
                } else {
                    errorDescriptors.append(errorDescriptor!)
                }
                
                if conversations.count + errorDescriptors.count == withIdentifiers.count {
                    completion(conversations.isEmpty ? nil : conversations,
                               errorDescriptors.isEmpty ? nil : "Failed: \(errorDescriptors.joined(separator: "\n"))")
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Updating Functions */
    
    public func updateConversation(_ conversation: Conversation,
                                   completion: @escaping (_ returnedConversation: Conversation?,
                                                          _ errorDescriptor: String?) -> Void) {
        //Want to get messages from current conversation and update it with messages we don't have.
        Database.database().reference().child("/allConversations/\(conversation.identifier.key!)").observeSingleEvent(of: .value, with: { (returnedSnapshot) in
            guard let snapshot = returnedSnapshot.value as? NSDictionary,
                  let data = snapshot as? [String: Any] else {
                completion(nil, "Couldn't convert snapshot to data.")
                return
            }
            
            guard let messageIdentifiers = data["messages"] as? [String]/*,
                                                                         let hash = data["hash"] as? String*/ else {
                completion(nil, "Unable to retrieve the specified data.")
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
                                                                                    errorDescriptor) in
                guard let messages = returnedMessages else {
                    completion(nil, errorDescriptor ?? "An unknown error occurred.")
                    return
                }
                
                updatedConversation.messages.append(contentsOf: messages)
                updatedConversation.messages = updatedConversation.sortedFilteredMessages()
                
                completion(updatedConversation, nil)
            }
            
        }) { (error) in
            completion(nil, "Unable to retrieve the specified data. (\(Logger.errorInfo(error)))")
        }
    }
    
    public func updateConversations(_ conversations: [Conversation],
                                    completion: @escaping (_ returnedConversations: [Conversation]?,
                                                           _ errorDescriptor: String?) -> Void) {
        let dispatchGroup = DispatchGroup()
        
        var errors = [String]()
        var updatedConversations = [Conversation]()
        
        for conversation in conversations {
            dispatchGroup.enter()
            
            self.updateConversation(conversation) { (returnedConversation,
                                                     errorDescriptor) in
                guard let conversation = returnedConversation else {
                    errors.append(errorDescriptor ?? "An unknown error occurred.")
                    
                    dispatchGroup.leave()
                    return
                }
                
                updatedConversations.append(conversation)
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if updatedConversations.count + errors.count == conversations.count {
                completion(updatedConversations.isEmpty ? nil : updatedConversations,
                           errors.isEmpty ? nil : errors.joined(separator: "\n"))
            } else {
                completion(nil, "Mismatched conversation input/output.")
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func deSerializeConversation(fromData: [String: Any],
                                         completion: @escaping(_ deSerializedConversation: Conversation?,
                                                               _ errorDescriptor: String?) -> Void) {
        guard let identifier = fromData["identifier"] as? String else {
            completion(nil, "Unable to deserialize «identifier».")
            return
        }
        
        guard let messageIdentifiers = fromData["messages"] as? [String] else {
            completion(nil, "Unable to deserialize «messages».")
            return
        }
        
        guard let participants = fromData["participants"] as? [String],
              let deSerializedParticipants = participants.asParticipants else {
            completion(nil, "Unable to deserialize «participants».")
            return
        }
        
        guard let lastModifiedString = fromData["lastModified"] as? String else {
            completion(nil, "Unable to deserialize «lastModifiedString».")
            return
        }
        
        //#warning("Why does «secondaryDateFormatter» not work in testing, but this does?")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        formatter.locale = Locale(identifier: "en_GB")
        
        guard let lastModifiedDate = formatter.date(from: lastModifiedString) else {
            completion(nil, "Unable to convert «lastModified» to Date.")
            return
        }
        
        guard let hash = fromData["hash"] as? String else {
            completion(nil, "Unable to deserialize «hash».")
            return
        }
        
        let conversationID = ConversationID(key: identifier,
                                            hash: hash)
        
        MessageSerializer.shared.getMessages(withIdentifiers: messageIdentifiers) { (returnedMessages,
                                                                                     getMessagesStatus) in
            guard let messages = returnedMessages else {
                completion(nil, getMessagesStatus ?? "An unknown error occurred.")
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
                                    completion: @escaping (_ errorDescriptor: String?) -> Void) {
        let database = Database.database().reference()
        
        for (index, participant) in forUsers.enumerated() {
            let key = "/allUsers/\(participant.userID!)/openConversations"
            
            database.child(key).observeSingleEvent(of: .value) { (returnedSnapshot) in
                guard var conversationIdStrings = returnedSnapshot.value as? [String] else {
                    completion("Unable to get conversation IDs for this user.")
                    return
                }
                
                conversationIdStrings.removeAll(where: { $0.hasPrefix(withIdentifier) })
                
                if conversationIdStrings.isEmpty {
                    conversationIdStrings = ["!"]
                }
                
                GeneralSerializer.setValue(onKey: key,
                                           withData: conversationIdStrings) { (returnedError) in
                    if let error = returnedError {
                        completion(Logger.errorInfo(error))
                    }
                    
                    if index == forUsers.count - 1 {
                        completion(nil)
                    }
                }
            } //Not adding error for now. Might want to break this up.
        }
    }
    
    private func deleteMessages(fromConversation withID: String,
                                completion: @escaping (_ errorDescriptor: String?) -> Void) {
        let database = Database.database().reference()
        
        database.child("/allConversations/\(withID)/messages").observeSingleEvent(of: .value, with: { (returnedSnapshot) in
            guard let messageIdentifiers = returnedSnapshot.value as? [String] else {
                completion("Unable to get participants from this conversation.")
                return
            }
            
            for (index, identifier) in messageIdentifiers.enumerated() {
                GeneralSerializer.setValue(onKey: "/allMessages/\(identifier)",
                                           withData: NSNull()) { (returnedError) in
                    if let error = returnedError {
                        completion(Logger.errorInfo(error))
                    }
                    
                    if index == messageIdentifiers.count - 1 {
                        completion(nil)
                    }
                }
            }
        })
    }
}
