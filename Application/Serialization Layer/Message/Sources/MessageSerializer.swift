//
//  MessageSerializer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 01/05/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

/* Third-party Frameworks */
import Firebase

public struct MessageSerializer {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    public static let shared = MessageSerializer()
    
    //==================================================//
    
    /* MARK: - Creation Functions */
    
    public func createMessage(fromAccountWithIdentifier: String,
                              inConversationWithIdentifier: String?,
                              translation: Translation,
                              completion: @escaping(_ returnedMessage: Message?,
                                                    _ errorDescriptor: String?) -> Void) {
        currentUser?.updateLastActiveDate()
        
        var data: [String: Any] = [:]
        
        data["fromAccount"] = fromAccountWithIdentifier
        data["languagePair"] = translation.languagePair.asString()
        data["translationReference"] = translation.serialize().key
        data["readDate"] = "!"
        data["sentDate"] = secondaryDateFormatter.string(from: Date())
        
        guard let generatedKey = Database.database().reference().child("/allMessages/").childByAutoId().key else {
            log("Unable to generate key for new message.",
                metadata: [#file, #function, #line])
            
            completion(nil, "Unable to generate key for new message.")
            return
        }
        
        GeneralSerializer.updateValue(onKey: "/allMessages/\(generatedKey)",
                                      withData: data) { (returnedError) in
            if let error = returnedError {
                completion(nil, errorInfo(error))
            }
        }
        
        guard let conversationIdentifier = inConversationWithIdentifier else {
            let message = Message(identifier: generatedKey,
                                  fromAccountIdentifier: fromAccountWithIdentifier,
                                  languagePair: translation.languagePair,
                                  translation: translation,
                                  readDate: nil,
                                  sentDate: Date())
            
            completion(message, nil)
            return
        }
        
        GeneralSerializer.getValues(atPath: "/allConversations/\(conversationIdentifier)/messages") { (returnedMessages, errorDescriptor) in
            if var messages = returnedMessages as? [String] {
                messages.append(generatedKey)
                
                GeneralSerializer.updateValue(onKey: "/allConversations/\(conversationIdentifier)",
                                              withData: ["messages": messages.filter({$0 != "!"})]) { (returnedError) in
                    if let error = returnedError {
                        completion(nil, errorInfo(error))
                    } else {
                        let message = Message(identifier: generatedKey,
                                              fromAccountIdentifier: fromAccountWithIdentifier,
                                              languagePair: translation.languagePair,
                                              translation: translation,
                                              readDate: nil,
                                              sentDate: Date())
                        
                        completion(message, nil)
                    }
                }
            } else {
                completion(nil, errorDescriptor ?? "An unknown error occurred.")
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Retrieval Functions */
    
    public func getMessage(withIdentifier: String,
                           completion: @escaping(_ returnedMessage: Message?,
                                                 _ errorDescriptor: String?) -> Void) {
        Database.database().reference().child("allMessages").child(withIdentifier).observeSingleEvent(of: .value, with: { (returnedSnapshot) in
            if let returnedSnapshotAsDictionary = returnedSnapshot.value as? NSDictionary,
               let asData = returnedSnapshotAsDictionary as? [String: Any] {
                var mutableData = asData
                
                mutableData["identifier"] = withIdentifier
                
                self.deSerializeMessage(fromData: mutableData) { (returnedMessage,
                                                                  errorDescriptor) in
                    guard returnedMessage != nil || errorDescriptor != nil else {
                        completion(nil, "An unknown error occurred.")
                        return
                    }
                    
                    if let error = errorDescriptor { 
                        completion(nil, error)
                    } else if let message = returnedMessage {
                        completion(message, nil)
                    }
                }
            } else {
                completion(nil, "No message exists with the identifier \"\(withIdentifier)\".")
            }
        }) { (error) in
            completion(nil, "Unable to retrieve the specified data. (\(errorInfo(error)))")
        }
    }
    
    public func getMessages(withIdentifiers: [String],
                            completion: @escaping(_ returnedMessages: [Message]?,
                                                  _ status: String?) -> Void) {
        var messages = [Message]()
        var errorDescriptors = [String]()
        
        if withIdentifiers == ["!"] {
            log("Null/first message processed.",
                metadata: [#file, #function, #line])
            completion([], nil)
        } else {
            guard !withIdentifiers.isEmpty else {
                completion(nil, "No identifiers passed!")
                return
            }
            
            for identifier in withIdentifiers {
                getMessage(withIdentifier: identifier) { (returnedMessage,
                                                          errorDescriptor) in
                    if let message = returnedMessage {
                        messages.append(message)
                    } else {
                        errorDescriptors.append(errorDescriptor!)
                    }
                    
                    if messages.count + errorDescriptors.count == withIdentifiers.count {
                        completion(messages.count == 0 ? nil : messages,
                                   errorDescriptors.count == 0 ? nil : "Failed: \(errorDescriptors.joined(separator: "\n"))")
                    }
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func deSerializeMessage(fromData: [String: Any],
                                    completion: @escaping(_ deSerializedMessage: Message?,
                                                          _ errorDescriptor: String?) -> Void) {
        guard let identifier = fromData["identifier"] as? String else {
            completion(nil, "Unable to deserialize «identifier».")
            return
        }
        
        guard let fromAccountIdentifier = fromData["fromAccount"] as? String else {
            completion(nil, "Unable to deserialize «fromAccount».")
            return
        }
        
        guard let languagePairString = fromData["languagePair"] as? String else {
            completion(nil, "Unable to deserialize «languagePairString».")
            return
        }
        
        guard let languagePair = languagePairString.asLanguagePair() else {
            completion(nil, "Unable to convert «languagePairString» to LanguagePair.")
            return
        }
        
        guard let translationReference = fromData["translationReference"] as? String else {
            completion(nil, "Unable to deserialize «translationReference».")
            return
        }
        
        guard let readDateString = fromData["readDate"] as? String else {
            completion(nil, "Unable to deserialize «readDate».")
            return
        }
        
        guard let sentDateString = fromData["sentDate"] as? String else {
            completion(nil, "Unable to deserialize «sentDate».")
            return
        }
        
        guard let sentDate = secondaryDateFormatter.date(from: sentDateString) else {
            completion(nil, "Unable to convert «sentDateString» to Date.")
            return
        }
        
        guard let archivedTranslation = TranslationArchiver.getFromArchive(withReference: translationReference, languagePair: languagePair) else {
            TranslationSerializer.findTranslation(withReference: translationReference,
                                                  languagePair: languagePair) { (returnedTranslation,
                                                                                 errorDescriptor) in
                guard returnedTranslation != nil || errorDescriptor != nil else {
                    completion(nil, "An unknown error occurred.")
                    return
                }
                
                if let error = errorDescriptor {
                    completion(nil, error)
                } else if let translation = returnedTranslation {
                    let readDate = secondaryDateFormatter.date(from: readDateString) ?? nil
                    
                    let deSerializedMessage = Message(identifier: identifier,
                                                      fromAccountIdentifier: fromAccountIdentifier,
                                                      languagePair: languagePair,
                                                      translation: translation,
                                                      readDate: readDate,
                                                      sentDate: sentDate)
                    
                    completion(deSerializedMessage, nil)
                }
            }
            
            return
        }
        
        let readDate = secondaryDateFormatter.date(from: readDateString) ?? nil
        
        let deSerializedMessage = Message(identifier: identifier,
                                          fromAccountIdentifier: fromAccountIdentifier,
                                          languagePair: languagePair,
                                          translation: archivedTranslation,
                                          readDate: readDate,
                                          sentDate: sentDate)
        
        completion(deSerializedMessage, nil)
    }
}
