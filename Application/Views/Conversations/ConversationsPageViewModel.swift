//
//  ConversationsPageViewModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 30/06/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import Firebase

public class ConversationsPageViewModel: ObservableObject {
    
    //==================================================//
    
    /* MARK: - Enumerated Type Declarations */
    
    public enum State {
        case idle
        case loading
        case failed(String)
        case loaded(translations: [String: Translation],
                    conversations: [Conversation])
    }
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    //Other Declarations
    private let inputs = ["messages": TranslationInput("Messages")]
    
    @Published private(set) var state = State.idle
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
    public func load() {
        state = .loading
        
        self.updateConversations { (returnedConversations,
                                    errorDescriptor) in
            guard let conversations = returnedConversations else {
                log(errorDescriptor ?? "An unknown error occurred.",
                    metadata: [#file, #function, #line])
                return
            }
            
            TranslatorService.main.getTranslations(for: Array(self.inputs.values),
                                                   languagePair: LanguagePair(from: "en",
                                                                              to: languageCode),
                                                   requiresHUD: false,
                                                   using: .random) { (returnedTranslations,
                                                                      errorDescriptors) in
                if let translations = returnedTranslations {
                    guard let matchedTranslations = translations.matchedTo(self.inputs) else {
                        self.state = .failed("Couldn't match translations with inputs.")
                        return
                    }
                    
                    self.state = .loaded(translations: matchedTranslations,
                                         conversations: conversations)
                } else if let errors = errorDescriptors {
                    log(errors.keys.joined(separator: "\n"),
                        metadata: [#file, #function, #line])
                    
                    self.state = .failed(errors.keys.joined(separator: "\n"))
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    func updateConversations(completion: @escaping(_ returnedConversations: [Conversation]?,
                                                   _ errorDescriptor: String?) -> Void = { _,_  in }) {
        guard let user = currentUser else {
            after(seconds: 1) {
                self.updateConversations { (returnedConversations,
                                            errorDescriptor) in
                    guard let conversations = returnedConversations else {
                        completion(nil, errorDescriptor ?? "An unknown error occurred.")
                        return
                    }
                    
                    completion(conversations, nil)
                }
            }
            return
        }
        
        guard !user.isUpdatingConversations else {
            after(seconds: 1) {
                self.updateConversations { (returnedConversations,
                                            errorDescriptor) in
                    guard let conversations = returnedConversations else {
                        completion(nil, errorDescriptor ?? "An unknown error occurred.")
                        return
                    }
                    
                    completion(conversations, nil)
                }
            }
            return
        }
        
        user.updateConversationData { (returnedConversations,
                                       errorDescriptor) in
            guard let conversations = returnedConversations else {
                completion(nil, errorDescriptor ?? "An unknown error occurred.")
                return
            }
            
            completion(conversations, nil)
        }
    }
    
    func randomLanguageCode() -> String {
        return ["af", "ga", "sq", "it", "ar", "ja", "az", "kn", "eu", "ko", "bn", "la", "be", "lv", "bg", "lt", "ca", "mk", "zh-CN", "ms", "zh-TW", "mt", "hr", "no", "cs", "fa", "da", "pl", "nl", "pt", "ro", "eo", "ru", "et", "sr", "tl", "sk", "fi", "sl", "fr", "es", "gl", "sw", "ka", "sv", "de", "ta", "el", "te", "gu", "th", "ht", "tr", "iw", "uk", "hi", "ur", "hu", "vi", "is", "cy", "id", "yi"].randomElement()!
    }
}
