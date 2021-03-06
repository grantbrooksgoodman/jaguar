//
//  ConversationSerializer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 01/05/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

/* Third-party Frameworks */
import Firebase

public struct ConversationSerializer {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    public static let shared = ConversationSerializer()
    
    //==================================================//
    
    /* MARK: - Creation Functions */
    
    public func createConversation(initialMessageIdentifier: String,
                                   participantIdentifiers: [String],
                                   completion: @escaping(_ returnedIdentifier: String?,
                                                         _ errorDescriptor: String?) -> Void) {
        currentUser?.updateLastActiveDate()
        
        var data: [String: Any] = [:]
        
        data["messages"] = [initialMessageIdentifier]
        data["participants"] = participantIdentifiers
        data["lastModified"] = secondaryDateFormatter.string(from: Date())
        
        guard let generatedKey = Database.database().reference().child("/allConversations/").childByAutoId().key else {
            log("Unable to generate key for new conversation.",
                metadata: [#file, #function, #line])
            
            completion(nil, "Unable to generate key for new conversation.")
            return
        }
        
        GeneralSerializer.updateValue(onKey: "/allConversations/\(generatedKey)",
                                      withData: data) { (returnedError) in
            if let error = returnedError {
                completion(nil, errorInfo(error))
            } else {
                var finalErrorDescriptor = ""
                
                let dispatchGroup = DispatchGroup()
                
                for userID in participantIdentifiers {
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
            if let returnedSnapshotAsDictionary = returnedSnapshot.value as? NSDictionary,
               let asData = returnedSnapshotAsDictionary as? [String: Any] {
                var mutableData = asData
                
                mutableData["identifier"] = withIdentifier
                
                self.deSerializeConversation(fromData: mutableData) { (returnedConversation,
                                                                       errorDescriptor) in
                    if let conversation = returnedConversation {
                        completion(conversation, nil)
                    } else {
                        completion(nil, errorDescriptor!)
                    }
                }
            } else {
                completion(nil, "No conversation exists with the identifier \"\(withIdentifier)\".")
            }
        }) { (error) in
            completion(nil, "Unable to retrieve the specified data. (\(errorInfo(error)))")
        }
    }
    
    public func getConversations(withIdentifiers: [String],
                                 completion: @escaping(_ returnedConversations: [Conversation]?,
                                                       _ errorDescriptor: String?) -> Void) {
        var conversations = [Conversation]()
        var errorDescriptors = [String]()
        
        guard !withIdentifiers.isEmpty else {
            completion(nil, "No identifiers passed!")
            return
        }
        
        for identifier in withIdentifiers {
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
        
        guard let messages = fromData["messages"] as? [String] else {
            completion(nil, "Unable to deserialize «messages».")
            return
        }
        
        guard let participants = fromData["participants"] as? [String] else {
            completion(nil, "Unable to deserialize «participants».")
            return
        }
        
        guard let lastModifiedString = fromData["lastModified"] as? String else {
            completion(nil, "Unable to deserialize «lastModifiedString».")
            return
        }
        
        guard let lastModifiedDate = secondaryDateFormatter.date(from: lastModifiedString) else {
            completion(nil, "Unable to convert «lastModified» to Date.")
            return
        }
        
        MessageSerializer.shared.getMessages(withIdentifiers: messages) { (returnedMessages,
                                                                           getMessagesStatus) in
            
            if let messages = returnedMessages {
                let deSerializedConversation = Conversation(identifier: identifier,
                                                            messages: messages,
                                                            lastModifiedDate: lastModifiedDate,
                                                            participantIdentifiers: participants)
                
                completion(deSerializedConversation, nil)
            } else if let status = getMessagesStatus {
                completion(nil, status)
            }
        }
    }
}
