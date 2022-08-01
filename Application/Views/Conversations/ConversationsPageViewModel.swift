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
import Translator

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
                let error = errorDescriptor ?? "An unknown error occurred."
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                self.state = .failed(error)
                return
            }
            
            let dataModel = PageViewDataModel(inputs: self.inputs)
            
            dataModel.translateStrings { (returnedTranslations,
                                          errorDescriptor) in
                guard let translations = returnedTranslations else {
                    let error = errorDescriptor ?? "An unknown error occurred."
                    
                    Logger.log(error,
                               metadata: [#file, #function, #line])
                    
                    self.state = .failed(error)
                    return
                }
                
                self.state = .loaded(translations: translations,
                                     conversations: conversations)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    public func createConversation(withUser: User) {
        ConversationSerializer.shared.createConversation(initialMessageIdentifier: "!",
                                                         participantIdentifiers: [currentUserID,
                                                                                  withUser.identifier]) { (returnedIdentifier, errorDescriptor) in
            
            guard let identifier = returnedIdentifier else {
                Logger.log(errorDescriptor ?? "An unknown error occurred.",
                           metadata: [#file, #function, #line])
                return
            }
            
            currentUser!.deSerializeConversations { (returnedConversations,
                                                     errorDescriptor) in
                guard let deSerializedConversations = returnedConversations else {
                    Logger.log(errorDescriptor ?? "An unknown error occurred.",
                               metadata: [#file, #function, #line])
                    return
                }
                
                updated = true
                conversations = deSerializedConversations
                
                for (index, conversation) in conversations.enumerated() {
                    conversation.setOtherUser { (errorDescriptor) in
                        Logger.log(errorDescriptor ?? "Set other user.",
                                   metadata: [#file, #function, #line])
                        if index == conversations.count - 1 {
                            self.load()
                        }
                    }
                }
            }
            
            print("new conversation with id: \(identifier)")
        }
    }
    
    public func getCellTitle(forUser: User) -> String {
        let phoneNumber = forUser.phoneNumber!
        var cellTitle = phoneNumber.callingCodeFormatted(region: forUser.region)
        
        if let name = ContactsServer.fetchContactName(forNumber: phoneNumber) {
            cellTitle = "\(name.givenName) \(name.familyName)"
        }
        
        return cellTitle
    }
    
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
    
    //    func randomLanguageCode() -> String {
    //        return ["af", "ga", "sq", "it", "ar", "ja", "az", "kn", "eu", "ko", "bn", "la", "be", "lv", "bg", "lt", "ca", "mk", "zh-CN", "ms", "zh-TW", "mt", "hr", "no", "cs", "fa", "da", "pl", "nl", "pt", "ro", "eo", "ru", "et", "sr", "tl", "sk", "fi", "sl", "fr", "es", "gl", "sw", "ka", "sv", "de", "ta", "el", "te", "gu", "th", "ht", "tr", "iw", "uk", "hi", "ur", "hu", "vi", "is", "cy", "id", "yi"].randomElement()!
    //    }
    
    public func startConversation() {
        guard let contact = selectedContact else {
            Logger.log("Contact selection was not processed.",
                       metadata: [#file, #function, #line])
            return
        }
        
        let dispatchGroup = DispatchGroup()
        var foundUser: User?
        
        for (index, phoneNumber) in contact.phoneNumbers.enumerated() {
            dispatchGroup.enter()
            
            #warning("ACCOUNT FOR NOT HAVING PREFIX CODE!!")
            UserSerializer.shared.findUser(byPhoneNumber: phoneNumber.value.stringValue.digits) { (returnedUser, errorDescriptor) in
                dispatchGroup.leave()
                
                guard let user = returnedUser else {
                    if index == contact.phoneNumbers.count - 1 {
                        let noUserString = "No user exists with the provided phone number."
                        
                        Logger.log(errorDescriptor ?? "An unknown error occurred.",
                                   with: errorDescriptor == noUserString ? .none : .errorAlert,
                                   metadata: [#file, #function, #line])
                        
                        if errorDescriptor == noUserString {
                            let alert = AKAlert(message: "\(noUserString)\n\nWould you like to send them an invite to sign up?",
                                                actions: [AKAction(title: "Send Invite",
                                                                   style: .preferred)])
                            alert.present { (actionID) in
                                if actionID != -1 {
                                    print("wants to invite")
                                }
                            }
                        }
                    }
                    
                    return
                }
                
                foundUser = user
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if let user = foundUser {
                guard user.phoneNumber.digits != currentUser!.phoneNumber.digits else {
                    Logger.log("Cannot start a conversation with yourself.",
                               with: .errorAlert,
                               metadata: [#file, #function, #line])
                    return
                }
                
                currentUser!.deSerializeConversations(completion: { (returnedConversations,
                                                                     errorDescriptor) in
                    guard let conversations = returnedConversations else {
                        Logger.log(errorDescriptor ?? "An unknown error occurred.",
                                   metadata: [#file, #function, #line])
                        return
                    }
                    
                    if conversations.contains(where: { $0.participantIdentifiers.contains(where: { $0.id == user.identifier }) }) {
                        Logger.log("Conversation with this user alreasdy exists.",
                                   with: .errorAlert,
                                   metadata: [#file, #function, #line])
                    } else {
                        self.createConversation(withUser: user)
                    }
                })
            }
        }
    }
}
