//
//  MessageSerializer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 01/05/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import Firebase
import FirebaseDatabase
import Translator

public struct MessageSerializer {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public static let shared = MessageSerializer()
    
    //==================================================//
    
    /* MARK: - Creation Methods */
    
    public func createMessage(fromAccountWithIdentifier: String,
                              inConversationWithIdentifier: String?,
                              translation: Translation,
                              audioComponent: (input: AudioFile, output: AudioFile)?,
                              completion: @escaping(_ returnedMessage: Message?,
                                                    _ exception: Exception?) -> Void) {
        RuntimeStorage.currentUser?.updateLastActiveDate()
        
        var data: [String: Any] = [:]
        
        data["fromAccount"] = fromAccountWithIdentifier
        data["languagePair"] = translation.languagePair.asString()
        data["translationReference"] = translation.serialize().key
        data["readDate"] = "!"
        data["sentDate"] = Core.secondaryDateFormatter!.string(from: Date())
        data["hasAudioComponent"] = audioComponent == nil ? "false" : "true"
        
        guard let generatedKey = Database.database().reference().child(GeneralSerializer.environment.shortString).child("/messages/").childByAutoId().key else {
            Logger.log("Unable to generate key for new message.",
                       metadata: [#file, #function, #line])
            
            completion(nil, Exception("Unable to generate key for new message.",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        let messagesPrefix = "/\(GeneralSerializer.environment.shortString)/messages/"
        GeneralSerializer.updateValue(onKey: "\(messagesPrefix)\(generatedKey)",
                                      withData: data) { (returnedError) in
            if let error = returnedError {
                completion(nil, Exception(error, metadata: [#file, #function, #line]))
            }
        }
        
        guard let conversationIdentifier = inConversationWithIdentifier else {
            let message = Message(identifier: generatedKey,
                                  fromAccountIdentifier: fromAccountWithIdentifier,
                                  languagePair: translation.languagePair,
                                  translation: translation,
                                  readDate: nil,
                                  sentDate: Date(),
                                  hasAudioComponent: audioComponent != nil)
            
            guard message.hasAudioComponent,
                  let audioComponent else {
                completion(message, nil)
                return
            }
            
            AudioMessageSerializer.shared.uploadAudioReference(for: message,
                                                               audioComponent: audioComponent) { newMessage, exception in
                guard exception == nil else {
                    completion(newMessage, exception!)
                    return
                }
                
                completion(newMessage, nil)
            }
            
            return
        }
        
        // #warning("Fix this for ConversationTestingSerializer.")
        let conversationsPrefix = "/\(GeneralSerializer.environment.shortString)/conversations/"
        GeneralSerializer.getValues(atPath: "\(conversationsPrefix)\(conversationIdentifier)/messages") { (returnedMessages, exception) in
            if var messages = returnedMessages as? [String] {
                messages.append(generatedKey)
                
                GeneralSerializer.updateValue(onKey: "\(conversationsPrefix)\(conversationIdentifier)",
                                              withData: ["messages": messages.filter({$0 != "!"})]) { (returnedError) in
                    guard let error = returnedError else {
                        let message = Message(identifier: generatedKey,
                                              fromAccountIdentifier: fromAccountWithIdentifier,
                                              languagePair: translation.languagePair,
                                              translation: translation,
                                              readDate: nil,
                                              sentDate: Date(),
                                              hasAudioComponent: audioComponent != nil)
                        
                        guard message.hasAudioComponent,
                              let audioComponent else {
                            completion(message, nil)
                            return
                        }
                        
                        AudioMessageSerializer.shared.uploadAudioReference(for: message,
                                                                           audioComponent: audioComponent) { newMessage, exception in
                            guard exception == nil else {
                                completion(newMessage, exception!)
                                return
                            }
                            
                            completion(newMessage, nil)
                        }
                        
                        return
                    }
                    
                    completion(nil, Exception(error, metadata: [#file, #function, #line]))
                }
            } else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Retrieval Methods */
    
    public func getMessage(withIdentifier: String,
                           completion: @escaping(_ returnedMessage: Message?,
                                                 _ exception: Exception?) -> Void) {
        guard withIdentifier != "!" else {
            completion(nil, Exception("Null/first message processed.",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        Database.database().reference().child(GeneralSerializer.environment.shortString).child("messages").child(withIdentifier).observeSingleEvent(of: .value, with: { (returnedSnapshot) in
            guard let snapshot = returnedSnapshot.value as? NSDictionary,
                  var data = snapshot as? [String: Any] else {
                completion(nil, Exception("No message exists with the provided identifier.",
                                          extraParams: ["MessageID": withIdentifier],
                                          metadata: [#file, #function, #line]))
                return
            }
            
            data["identifier"] = withIdentifier
            
            self.deSerializeMessage(fromData: data) { (returnedMessage,
                                                       exception) in
                guard let message = returnedMessage else {
                    let error = exception ?? Exception(metadata: [#file, #function, #line])
                    
                    Logger.log(error)
                    completion(nil, error)
                    return
                }
                
                completion(message, nil)
            }
        }) { (error) in
            completion(nil, Exception(error,
                                      metadata: [#file, #function, #line]))
        }
    }
    
    public func getMessages(withIdentifiers: [String],
                            completion: @escaping(_ returnedMessages: [Message]?,
                                                  _ exception: Exception?) -> Void) {
        var messages = [Message]()
        var exceptions = [Exception]()
        
        if withIdentifiers == ["!"] {
            Logger.log("Null/first message processed.",
                       verbose: true,
                       metadata: [#file, #function, #line])
            completion([], nil)
        } else {
            guard !withIdentifiers.isEmpty else {
                completion(nil, Exception("No identifiers passed!",
                                          metadata: [#file, #function, #line]))
                return
            }
            
            for identifier in withIdentifiers {
                getMessage(withIdentifier: identifier) { (returnedMessage,
                                                          exception) in
                    if let message = returnedMessage {
                        messages.append(message)
                    } else {
                        exceptions.append(exception ?? Exception(metadata: [#file, #function, #line]))
                    }
                    
                    if messages.count + exceptions.count == withIdentifiers.count {
                        completion(messages.isEmpty ? nil : messages,
                                   exceptions.compiledException)
                    }
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func deSerializeMessage(fromData: [String: Any],
                                    completion: @escaping(_ deSerializedMessage: Message?,
                                                          _ exception: Exception?) -> Void) {
        guard let identifier = fromData["identifier"] as? String else {
            completion(nil, Exception("Unable to deserialize «identifier».",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        guard let fromAccountIdentifier = fromData["fromAccount"] as? String else {
            completion(nil, Exception("Unable to deserialize «fromAccount».",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        guard let languagePairString = fromData["languagePair"] as? String else {
            completion(nil, Exception("Unable to deserialize «languagePairString».",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        guard let languagePair = languagePairString.asLanguagePair() else {
            completion(nil, Exception("Unable to convert «languagePairString» to LanguagePair.",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        guard let translationReference = fromData["translationReference"] as? String else {
            completion(nil, Exception("Unable to deserialize «translationReference».",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        guard let readDateString = fromData["readDate"] as? String else {
            completion(nil, Exception("Unable to deserialize «readDate».",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        guard let sentDateString = fromData["sentDate"] as? String else {
            completion(nil, Exception("Unable to deserialize «sentDate».",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        // #warning("Why does «secondaryDateFormatter» not work in testing, but this does?")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        formatter.locale = Locale(identifier: "en_GB")
        
        guard let sentDate = formatter.date(from: sentDateString) else {
            completion(nil, Exception("Unable to convert «sentDateString» to Date.",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        let readDate = Core.secondaryDateFormatter!.date(from: readDateString) ?? nil
        
        guard let hasAudioComponentString = fromData["hasAudioComponent"] as? String,
              hasAudioComponentString == "true" || hasAudioComponentString == "false" else {
            completion(nil, Exception("Unable to deserialize «hasAudioComponent».",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        let hasAudioComponent = hasAudioComponentString == "true" ? true : false
        
        guard let archivedTranslation = TranslationArchiver.getFromArchive(withReference: translationReference, languagePair: languagePair) else {
            TranslationSerializer.findTranslation(withReference: translationReference,
                                                  languagePair: languagePair) { (returnedTranslation,
                                                                                 exception) in
                guard let translation = returnedTranslation else {
                    let error = exception ?? Exception(metadata: [#file, #function, #line])
                    
                    Logger.log(error)
                    completion(nil, error)
                    return
                }
                
                let deSerializedMessage = Message(identifier: identifier,
                                                  fromAccountIdentifier: fromAccountIdentifier,
                                                  languagePair: languagePair,
                                                  translation: translation,
                                                  readDate: readDate,
                                                  sentDate: sentDate,
                                                  hasAudioComponent: hasAudioComponent)
                
                guard deSerializedMessage.hasAudioComponent else {
                    completion(deSerializedMessage, nil)
                    return
                }
                
                AudioMessageSerializer.shared.retrieveAudioReference(for: deSerializedMessage) { newMessage, exception in
                    guard exception == nil else {
                        completion(nil, exception!)
                        return
                    }
                    
                    completion(newMessage, nil)
                }
            }
            
            return
        }
        
        let deSerializedMessage = Message(identifier: identifier,
                                          fromAccountIdentifier: fromAccountIdentifier,
                                          languagePair: languagePair,
                                          translation: archivedTranslation,
                                          readDate: readDate,
                                          sentDate: sentDate,
                                          hasAudioComponent: hasAudioComponent)
        
        guard deSerializedMessage.hasAudioComponent else {
            completion(deSerializedMessage, nil)
            return
        }
        
        AudioMessageSerializer.shared.retrieveAudioReference(for: deSerializedMessage) { newMessage, exception in
            guard exception == nil else {
                completion(nil, exception!)
                return
            }
            
            completion(newMessage, nil)
        }
    }
}
