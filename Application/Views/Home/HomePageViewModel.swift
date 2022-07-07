//
//  HomePageViewModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 30/06/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import Firebase

public class HomePageViewModel: ObservableObject {
    
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
        
        TranslatorService.main.getTranslations(for: Array(inputs.values),
                                               languagePair: LanguagePair(from: "en",
                                                                          to: languageCode),
                                               requiresHUD: false,
                                               using: .google) { (returnedTranslations,
                                                                  errorDescriptors) in
            if let translations = returnedTranslations {
                guard let matchedTranslations = translations.matchedTo(self.inputs) else {
                    self.state = .failed("Couldn't match translations with inputs.")
                    return
                }
                
                var conversations = [Conversation]()
                
                after(milliseconds: 1000) {
                    if let conversationIdentifiers = currentUser!.openConversations {
                        ConversationSerializer.shared.getConversations(withIdentifiers: conversationIdentifiers) { (returnedConversations, errorDescriptor) in
                            if let error = errorDescriptor {
                                log(error, metadata: [#file, #function, #line])
                            } else {
                                conversations = returnedConversations ?? []
                                
                                let dispatchGroup = DispatchGroup()
                                
                                for conversation in conversations {
                                    dispatchGroup.enter()
                                    
                                    conversation.setOtherUser { (errorDescriptor) in
                                        if let error = errorDescriptor {
                                            log(error, metadata: [#file, #function, #line])
                                        }
                                        
                                        dispatchGroup.leave()
                                    }
                                }
                                
                                dispatchGroup.notify(queue: .main) {
                                    self.state = .loaded(translations: matchedTranslations,
                                                         conversations: conversations)
                                }
                            }
                        }
                    } else {
                        self.state = .loaded(translations: matchedTranslations,
                                             conversations: [])
                    }
                }
            } else if let errors = errorDescriptors {
                log(errors.keys.joined(separator: "\n"),
                    metadata: [#file, #function, #line])
                
                self.state = .failed(errors.keys.joined(separator: "\n"))
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    func addMessageToConversation() {
        TranslatorService.main.translate(TranslationInput("I'm pooping in my pants today."),
                                         with: LanguagePair(from: "en", to: randomLanguageCode())) { (returnedTranslation, errorDescriptor) in
            if let error = errorDescriptor {
                log(error, metadata: [#file, #function, #line])
            } else if let translation = returnedTranslation {
                MessageSerializer.shared.createMessage(fromAccountWithIdentifier: "gclSjUkq0YfHsPzz6OtwdCAoSKU2",
                                                       inConversationWithIdentifier: "-N6Jn61FjgnAk84-M7jx",
                                                       translation: translation) { (returnedIdentifier, errorDescriptor) in
                    if let error = errorDescriptor {
                        log(error, metadata: [#file, #function, #line])
                    } else {
                        print("new message with id \(returnedIdentifier!)")
                    }
                }
            }
        }
    }
    
    func getUser() {
        UserSerializer().getUser(withIdentifier: "r2wM8ue2FmWryaOyjSgYZtFP4CH3") { (returnedUser,
                                                                                    errorDescriptor) in
            if let error = errorDescriptor {
                log(error, metadata: [#file, #function, #line])
            } else {
                if let user = returnedUser {
                    user.deSerializeConversations { (returnedConversations,
                                                     errorDescriptor) in
                        if let error = errorDescriptor {
                            log(error, metadata: [#file, #function, #line])
                        } else {
                            if let conversations = returnedConversations {
                                print(conversations[0].lastModifiedDate ?? "")
                            } else {
                                log("An unknown error occurred.",
                                    metadata: [#file, #function, #line])
                            }
                        }
                    }
                } else {
                    log("Couldn't get user.",
                        metadata: [#file, #function, #line])
                }
            }
        }
    }
    
    func randomLanguageCode() -> String {
        return ["af", "ga", "sq", "it", "ar", "ja", "az", "kn", "eu", "ko", "bn", "la", "be", "lv", "bg", "lt", "ca", "mk", "zh-CN", "ms", "zh-TW", "mt", "hr", "no", "cs", "fa", "da", "pl", "nl", "pt", "ro", "eo", "ru", "et", "sr", "tl", "sk", "fi", "sl", "fr", "es", "gl", "sw", "ka", "sv", "de", "ta", "el", "te", "gu", "th", "ht", "tr", "iw", "uk", "hi", "ur", "hu", "vi", "is", "cy", "id", "yi"].randomElement()!
    }
}
