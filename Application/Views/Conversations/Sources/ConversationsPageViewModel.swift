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
import AlertKit
import Firebase
import Translator

public class ConversationsPageViewModel: ObservableObject {
    
    //==================================================//
    
    /* MARK: - Enumerated Type Declarations */
    
    public enum State {
        case idle
        case loading
        case failed(String)
        case loaded(translations: [String: Translator.Translation],
                    conversations: [Conversation])
    }
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    //Other Declarations
    public let inputs = ["messages": Translator.TranslationInput("Messages")]
    
    @Published private(set) var state = State.idle
    private var translations: [String: Translator.Translation]!
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
    public func load() {
        state = .loading
        
        printCurrentTime()
        
        ConversationArchiver.getArchive { (returnedTuple,
                                           errorDescriptor) in
            guard let tuple = returnedTuple else {
                Logger.log(errorDescriptor ?? "An unknown error occurred.",
                           metadata: [#file, #function, #line])
                return
            }
            
            if tuple.userID == currentUserID {
                var canLoad = true
                for conversation in tuple.conversations {
                    if conversation.otherUser == nil {
                        canLoad = false
                    }
                }
                
                var seenConversations = [Conversation]()
                for conversation in tuple.conversations {
                    if !seenConversations.contains(where: { $0.identifier == conversation.identifier }) {
                        seenConversations.append(conversation)
                    }
                }
                
                if canLoad {
                    self.translateAndLoad(conversations: seenConversations)
                }
            }
        }
        
        #warning("Make this asynchronous.")
        self.updateConversations { (returnedConversations,
                                    errorDescriptor) in
            printCurrentTime()
            
            Logger.log("Updated conversations.",
                       metadata: [#file, #function, #line])
            
            guard let conversations = returnedConversations else {
                let error = errorDescriptor ?? "An unknown error occurred."
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                self.state = .failed(error)
                return
            }
            
            var seenConversations = [Conversation]()
            for conversation in conversations {
                if !seenConversations.contains(where: { $0.identifier == conversation.identifier }) {
                    seenConversations.append(conversation)
                }
            }
            
            for conversation in seenConversations {
                self.setUpObserver(for: conversation)
            }
            
            self.state = .loading
            self.translateAndLoad(conversations: seenConversations)
        }
    }
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
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
                    
                    if conversations.contains(where: { $0.participants.contains(where: { $0.userID == user.identifier }) }) {
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
    
    public func updateConversations(completion: @escaping(_ returnedConversations: [Conversation]?,
                                                          _ errorDescriptor: String?) -> Void = { _,_  in }) {
        guard let user = currentUser,
              !user.isUpdatingConversations else {
            after(milliseconds: 100) {
                self.updateConversations { (returnedConversations,
                                            errorDescriptor) in
                    guard let conversations = returnedConversations else {
                        completion(nil, errorDescriptor ?? "An unknown error occurred.")
                        return
                    }
                    
                    ConversationArchiver.addToArchive(conversations)
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
            
            ConversationArchiver.addToArchive(conversations)
            completion(conversations, nil)
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func createConversation(withUser: User) {
        ConversationSerializer.shared.createConversation(initialMessageIdentifier: "!",
                                                         participants: [currentUserID,
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
                            ConversationArchiver.addToArchive(conversations)
                            //                            self.load()
                        }
                    }
                }
            }
            
            print("new conversation with id: \(identifier)")
        }
    }
    
    private func getCellTitle(forUser: User) -> String {
        let phoneNumber = forUser.phoneNumber!
        var cellTitle = phoneNumber.callingCodeFormatted(region: forUser.region)
        
        if let name = ContactsServer.fetchContactName(forNumber: phoneNumber) {
            cellTitle = "\(name.givenName) \(name.familyName)"
        }
        
        return cellTitle
    }
    
    //    private func randomLanguageCode() -> String {
    //        return ["af", "ga", "sq", "it", "ar", "ja", "az", "kn", "eu", "ko", "bn", "la", "be", "lv", "bg", "lt", "ca", "mk", "zh-CN", "ms", "zh-TW", "mt", "hr", "no", "cs", "fa", "da", "pl", "nl", "pt", "ro", "eo", "ru", "et", "sr", "tl", "sk", "fi", "sl", "fr", "es", "gl", "sw", "ka", "sv", "de", "ta", "el", "te", "gu", "th", "ht", "tr", "iw", "uk", "hi", "ur", "hu", "vi", "is", "cy", "id", "yi"].randomElement()!
    //    }
    
    private func setUpObserver(for conversation: Conversation) {
        Database.database().reference().child("/allConversations/\(conversation.identifier!)").observe(.childChanged) { (returnedSnapshot) in
            guard returnedSnapshot.key == "messages",
                  let messageIdentifiers = returnedSnapshot.value as? [String],
                  let newMessageID = messageIdentifiers.last else {
                return
            }
            
            self.state = .loading
            
            MessageSerializer.shared.getMessage(withIdentifier: newMessageID) { (returnedMessage,
                                                                                 errorDescriptor) in
                guard let message = returnedMessage else {
                    Logger.log(errorDescriptor ?? "An unknown error occurred.",
                               metadata: [#file, #function, #line])
                    return
                }
                
                conversation.messages.append(message)
                conversation.messages = conversation.sortedFilteredMessages()
                self.state = .loaded(translations: self.translations,
                                     conversations: conversations)
            }
        } withCancel: { (error) in
            Logger.log(error,
                       metadata: [#file, #function, #line])
        }
    }
    
    private func translateAndLoad(conversations: [Conversation]) {
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
            
            self.translations = translations
            self.state = .loaded(translations: translations,
                                 conversations: conversations)
        }
    }
}
