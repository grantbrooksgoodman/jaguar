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
import AlertKit
import FirebaseDatabase
import Translator

public enum ConversationTestingSerializer {
    
    //==================================================//
    
    /* MARK: - Conversation Creation */
    
    // #warning("LanguagePair generation is messed up.")
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
    
    /* MARK: - Conversation Deletion */
    
    public static func deleteAllConversations(completion: @escaping(_ exception: Exception?) -> Void) {
        removeConversationsForAllUsers { exception in
            guard exception == nil else {
                completion(exception!)
                return
            }
            
            let keys = ["conversations", "messages"]
            
            var exceptions = [Exception]()
            for (index, key) in keys.enumerated() {
                GeneralSerializer.setValue(onKey: "/\(GeneralSerializer.environment.shortString)/\(key)",
                                           withData: NSNull()) { returnedError in
                    if let error = returnedError {
                        exceptions.append(Exception(error, metadata: [#file, #function, #line]))
                    }
                }
                
                if index == keys.count - 1 {
                    guard exceptions.count == 0 else {
                        completion(exceptions.compiledException!)
                        return
                    }
                    
                    RuntimeStorage.currentUser?.openConversations = nil
                    ConversationArchiver.clearArchive()
                }
            }
        }
    }
    
    private static func removeConversationsForAllUsers(completion: @escaping(_ exception: Exception?) -> Void) {
        
        Database.database().reference().child(GeneralSerializer.environment.shortString).child("/users").observeSingleEvent(of: .value) { (returnedSnapshot) in
            guard let snapshot = returnedSnapshot.value as? NSDictionary,
                  let data = snapshot as? [String: Any] else {
                let exception = Exception("Couldn't get user list.",
                                          metadata: [#file, #function, #line])
                
                Logger.log(exception,
                           with: .errorAlert)
                completion(exception)
                
                return
            }
            
            var exceptions = [Exception]()
            for (index, identifier) in Array(data.keys).enumerated() {
                let pathPrefix = "/\(GeneralSerializer.environment.shortString)/users/"
                GeneralSerializer.setValue(onKey: "\(pathPrefix)\(identifier)/openConversations",
                                           withData: ["!"]) { returnedError in
                    if let error = returnedError {
                        let exception = Exception(error, metadata: [#file, #function, #line])
                        
                        Logger.log(exception)
                        exceptions.append(exception)
                    }
                }
                
                if index == Array(data.keys).count - 1 {
                    completion(exceptions.compiledException)
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Other Methods */
    
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
                                           translations: [Translator.Translation],
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
                                              completion: @escaping (_ returnedTranslations: [Translator.Translation]?,
                                                                     _ exception: Exception?) -> Void) {
        var inputs = [Translator.TranslationInput]()
        messages.forEach { message in
            inputs.append(Translator.TranslationInput(message))
        }
        
        var translations = [Translator.Translation]()
        for (index, input) in inputs.enumerated() {
            let languagesToUse = index % 2 == 0 ? languages : languages.reversed()
            let languagePair = Translator.LanguagePair(from: languagesToUse[0],
                                                       to: languagesToUse[1])
            
            print("using «\(languagePair.asString())» for index [\(index)]")
            
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
