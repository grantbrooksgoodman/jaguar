//
//  ConversationTestingSerializer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 28/10/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

/* Third-party Frameworks */
import Translator

public enum ConversationTestingSerializer {
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
#warning("LanguagePair generation is messed up.")
    public static func createRandomConversation(completion: @escaping (_ exception: Exception?) -> Void) {
        var mockMessages = ["Hello there!",
                            "Hi, how are you?",
                            "I'm well, thanks.",
                            "Good to hear it."]
        
        for _ in 0...2 {
            mockMessages.append(SentenceGenerator.generateSentence(wordCount: Int().random(min: 6, max: 50)))
        }
        
        UserTestingSerializer.shared.getRandomUserPair { returnedUsers, exception in
            guard let users = returnedUsers else {
                completion(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            self.createConversation(with: users,
                                    messages: mockMessages) { exception in
                completion(exception)
            }
        }
    }
    
    public static func createRandomConversations(_ amount: Int,
                                                 completion: @escaping (_ exception: Exception?) -> Void) {
        var exceptions = [Exception]()
        
        for index in 0...amount {
            createRandomConversation { exception in
                if let exception = exception {
                    exceptions.append(exception)
                }
                
                // amount - 1 ???
                if index == amount {
                    completion(exceptions.isEmpty ? nil : exceptions.compiledException)
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private static func createConversation(with users: [User],
                                           messages: [String],
                                           completion: @escaping(_ exception: Exception?) -> Void) {
        translateMockMessages(messages,
                              languages: [users[0].languageCode, users[1].languageCode]) { returnedTranslations, exception in
            guard let translations = returnedTranslations else {
                completion(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            ConversationSerializer.shared.createConversation(initialMessageIdentifier: "!",
                                                             participants: users.identifiers()) { returnedConversation, exception in
                guard let conversation = returnedConversation else {
                    completion(exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                self.createMockMessages(inConversationWithID: conversation.identifier.key,
                                        userIDs: users.identifiers(),
                                        translations: translations) { exception in
                    if let exception = exception {
                        completion(exception)
                    } else {
                        completion(nil)
                    }
                }
            }
        }
    }
    
    private static func createMockMessages(inConversationWithID: String,
                                           userIDs: [String],
                                           translations: [Translation],
                                           completion: @escaping(_ exception: Exception?) -> Void) {
        var exceptions = [Exception]()
        
        for (index, translation) in translations.enumerated() {
            MessageSerializer.shared.createMessage(fromAccountWithIdentifier: userIDs[index % 2],
                                                   inConversationWithIdentifier: inConversationWithID,
                                                   translation: translation) { _, exception in
                if let exception = exception {
                    exceptions.append(exception)
                }
                
                if index == translations.count - 1 {
                    completion(exceptions.isEmpty ? nil : exceptions.compiledException)
                }
            }
        }
    }
    
    private static func translateMockMessages(_ messages: [String],
                                              languages: [String],
                                              completion: @escaping (_ returnedTranslations: [Translation]?,
                                                                     _ exception: Exception?) -> Void) {
        var inputs = [TranslationInput]()
        messages.forEach { message in
            inputs.append(TranslationInput(message))
        }
        
        var translations = [Translation]()
        for (index, input) in inputs.enumerated() {
            let languagesToUse = index % 2 == 0 ? languages : languages.reversed()
            let languagePair = LanguagePair(from: languagesToUse[0],
                                            to: languagesToUse[1])
            
            FirebaseTranslator.shared.translate(input,
                                                with: languagePair) { returnedTranslation, exception in
                guard let translation = returnedTranslation else {
                    completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                translations.append(translation)
                
                if index == inputs.count - 1 {
                    completion(translations.isEmpty ? nil : translations,
                               translations.isEmpty ? Exception("No translations returned!",
                                                                metadata: [#file, #function, #line]) : nil)
                }
            }
        }
    }
}
