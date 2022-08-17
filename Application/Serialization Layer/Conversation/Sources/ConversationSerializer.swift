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
    
    /* MARK: - Struct-level Variable Declarations */
    
    public static let shared = ConversationSerializer()
    
    //==================================================//
    
    /* MARK: - Creation Functions */
    
    public func createConversation(initialMessageIdentifier: String,
                                   participants: [String],
                                   completion: @escaping(_ returnedIdentifier: String?,
                                                         _ errorDescriptor: String?) -> Void) {
        currentUser?.updateLastActiveDate()
        
        var data: [String: Any] = [:]
        
        var serializedParticipants = [String]()
        
        for identifier in participants {
            serializedParticipants.append("\(identifier) | false")
        }
        
        data["messages"] = [initialMessageIdentifier]
        data["participants"] = serializedParticipants
        data["lastModified"] = secondaryDateFormatter.string(from: Date())
        
        guard let generatedKey = Database.database().reference().child("/allConversations/").childByAutoId().key else {
            Logger.log("Unable to generate key for new conversation.",
                       metadata: [#file, #function, #line])
            
            completion(nil, "Unable to generate key for new conversation.")
            return
        }
        
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
                            
                            openConversations.append(generatedKey)
                            openConversations = openConversations.filter({$0 != "!"})
                            
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
                    completion(finalErrorDescriptor != "" ? nil : generatedKey,
                               finalErrorDescriptor == "" ? nil : finalErrorDescriptor.trimmingTrailingNewlines)
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Retrieval Functions */
    
    public func getConversation(withIdentifier: String,
                                completion: @escaping(_ returnedConversation: Conversation?,
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
            completion([], nil)
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
                    completion(conversations.count == 0 ? nil : conversations,
                               errorDescriptors.count == 0 ? nil : "Failed: \(errorDescriptors.joined(separator: "\n"))")
                }
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
        
        guard let participants = fromData["participants"] as? [String] else {
            completion(nil, "Unable to deserialize «participants».")
            return
        }
        
        var deSerializedParticipants = [Participant]()
        for participant in participants {
            guard participant.components(separatedBy: " | ").count == 2 else {
                completion(nil, "Unable to fully deserialize «participants».")
                return
            }
            
            let components = participant.components(separatedBy: " | ")
            let participant = Participant(userID: components[0],
                                          isTyping: components[1] == "true" ? true : false)
            
            deSerializedParticipants.append(participant)
        }
        
        guard let lastModifiedString = fromData["lastModified"] as? String else {
            completion(nil, "Unable to deserialize «lastModifiedString».")
            return
        }
        
        #warning("Why does «secondaryDateFormatter» not work in testing, but this does?")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        formatter.locale = Locale(identifier: "en_GB")
        
        guard let lastModifiedDate = formatter.date(from: lastModifiedString) else {
            completion(nil, "Unable to convert «lastModified» to Date.")
            return
        }
        
        let deSerializedConversation = Conversation(identifier: identifier,
                                                    messageIdentifiers: messageIdentifiers,
                                                    messages: [],
                                                    lastModifiedDate: lastModifiedDate,
                                                    participants: deSerializedParticipants)
        
        completion(deSerializedConversation, nil)
        deSerializedConversation.setMessages(); #warning("Account for this with a boolean?")
        
        //        MessageSerializer.shared.getMessages(withIdentifiers: messageIdentifiers) { (returnedMessages,
        //                                                                           getMessagesStatus) in
        //            guard let messages = returnedMessages else {
        //                completion(nil, getMessagesStatus ?? "An unknown error occurred.")
        //                return
        //            }
        //
        //            let deSerializedConversation = Conversation(identifier: identifier,
        //                                                        messageIdentifiers: messageIdentifiers,
        //                                                        messages: messages,
        //                                                        lastModifiedDate: lastModifiedDate,
        //                                                        participants: deSerializedParticipants)
        //
        //            completion(deSerializedConversation, nil)
        //        }
    }
}
