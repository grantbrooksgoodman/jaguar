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
    
    /* MARK: - Enums */
    
    public enum State {
        case idle
        case loading
        case failed(Exception)
        case loaded(translations: [String: Translator.Translation])
    }
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public let inputs = ["done": Translator.TranslationInput("Done", alternate: "Finish"),
                         "messages": Translator.TranslationInput("Messages")]
    
    @Published private(set) var state = State.idle
    private var translations: [String: Translator.Translation]!
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
    public func load(silent: Bool? = nil,
                     completion: @escaping() -> Void = { }) {
        let silent = silent ?? false
        if !silent {
            state = .loading
        }
        
        guard let currentUserID = RuntimeStorage.currentUserID else {
            state = .failed(Exception("No current user ID!",
                                      metadata: [#file, #function, #line]))
            completion()
            return
        }
        
        ContactService.clearCache()
        
        UserSerializer.shared.getUser(withIdentifier: currentUserID) { (returnedUser,
                                                                        exception) in
            guard let user = returnedUser else {
                Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                           with: .errorAlert)
                completion()
                return
            }
            
            UserDefaults.standard.setValue(currentUserID, forKey: "currentUserID")
            
            RuntimeStorage.store(user, as: .currentUser)
            
            RuntimeStorage.store(user.languageCode!, as: .languageCode)
            AKCore.shared.setLanguageCode(user.languageCode)
            
            user.deSerializeConversations { (returnedConversations,
                                             exception) in
                guard let conversations = returnedConversations else {
                    self.state = .failed(exception ?? Exception(metadata: [#file, #function, #line]))
                    completion()
                    return
                }
                
                //                conversations.forEach { conversation in
                //                    self.setUpObserver(for: conversation)
                //                }
                
                self.translateAndLoad(conversations: conversations) {
                    completion()
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Conversation Deletion */
    
    public func deleteConversation(withIdentifier: String) {
        ConversationSerializer.shared.deleteConversation(withIdentifier: withIdentifier) { (exception) in
            if let error = exception {
                Logger.log(error, with: .errorAlert)
            }
            
            guard let currentUser = RuntimeStorage.currentUser else {
                Logger.log(Exception("No current user!",
                                     metadata: [#file, #function, #line]),
                           with: .errorAlert)
                return
            }
            
            currentUser.deSerializeConversations { (returnedConversations,
                                                    exception) in
                guard let exception = exception else {
                    self.load()
                    return
                }
                
                Logger.log(exception, with: .errorAlert)
            }
        }
    }
    
    public func deleteConversation(at offsets: IndexSet) {
        guard let currentUser = RuntimeStorage.currentUser,
              let sortedConversations = currentUser.openConversations?.sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate }).unique(),
              let offset = offsets.first,
              offset < sortedConversations.count else { return }
        
        let selectedConversation = sortedConversations[offset]
        
        guard let otherUser = selectedConversation.otherUser else {
            selectedConversation.setOtherUser { exception in
                guard exception == nil else {
                    Logger.log(exception!,
                               with: .errorAlert)
                    return
                }
                
                self.deleteConversation(at: offsets)
            }
            
            return
        }
        
        let actionSheet = AKActionSheet(title: otherUser.cellTitle,
                                        message: "Are you sure you'd like to delete this conversation?\nThis operation cannot be undone.",
                                        actions: [AKAction(title: "Delete", style: .destructive)],
                                        shouldTranslate: [.message, .actions(indices: nil), .cancelButtonTitle],
                                        networkDependent: true)
        
        actionSheet.present { (actionID) in
            guard actionID == actionSheet.actions[0].identifier else {
                return
            }
            
            ConversationSerializer.shared.deleteConversation(withIdentifier: selectedConversation.identifier.key!) { (exception) in
                if let error = exception {
                    Logger.log(error, with: .errorAlert)
                }
                
                currentUser.deSerializeConversations { (returnedConversations,
                                                        exception) in
                    guard let exception = exception else {
                        self.load()
                        return
                    }
                    
                    Logger.log(exception, with: .errorAlert)
                }
            }
        }
    }
    
    private func removeConversationsForAllUsers(completion: @escaping(_ exception: Exception?) -> Void) {
        Database.database().reference().child("/allUsers").observeSingleEvent(of: .value) { (returnedSnapshot) in
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
                GeneralSerializer.setValue(onKey: "/allUsers/\(identifier)/openConversations",
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
    
    /* MARK: - Operation Confirmation */
    
    public func confirmSignOut(_ viewRouter: ViewRouter) {
        AKConfirmationAlert(title: "Log Out",
                            message: "Are you sure you would like to log out?",
                            confirmationStyle: .preferred).present { didConfirm in
            if didConfirm == 1 {
                self.signOut(viewRouter)
            }
        }
    }
    
    public func confirmTrashDatabase() {
        AKConfirmationAlert(title: "Destroy Database",
                            message: "Are you sure you'd like to trash the database? This operation cannot be undone.",
                            confirmationStyle: .destructivePreferred).present { didConfirm in
            if didConfirm == 1 {
                AKConfirmationAlert(title: "Are you sure?",
                                    message: "ALL CONVERSATIONS FOR ALL USERS WILL BE DELETED!",
                                    cancelConfirmTitles: (cancel: nil, confirm: "Yes, I'm sure"),
                                    confirmationStyle: .destructivePreferred).present { confirmed in
                    if confirmed == 1 {
                        self.trashDatabase()
                    }
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Miscellaneous Functions */
    
    public func reloadIfNeeded() {
        StateProvider.shared.hasDisappeared = false
        
        guard !RuntimeStorage.isPresentingChat! else { return }
        
        guard let previousConversations = RuntimeStorage.previousConversations,
              let openConversations = RuntimeStorage.currentUser?.openConversations,
              !previousConversations.matchesHashesOf(openConversations) else { return }
        
        RuntimeStorage.store(openConversations, as: .previousConversations)
        guard RuntimeStorage.currentFile!.hasSuffix("ConversationsPageView.swift") else { return }
        
        load(silent: true)
    }
    
    private func setUpObserver(for conversation: Conversation) {
        Database.database().reference().child("/allConversations/\(conversation.identifier!.key!)").observe(.childChanged) { (returnedSnapshot) in
            guard returnedSnapshot.key == "messages",
                  let messageIdentifiers = returnedSnapshot.value as? [String],
                  let newMessageID = messageIdentifiers.last else {
                return
            }
            
            self.state = .loading
            
            MessageSerializer.shared.getMessage(withIdentifier: newMessageID) { (returnedMessage,
                                                                                 exception) in
                guard let message = returnedMessage else {
                    Logger.log(exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                conversation.messages.append(message)
                conversation.messages = conversation.sortedFilteredMessages()
                RuntimeStorage.currentUser?.openConversations = RuntimeStorage.currentUser?.openConversations?.unique()
                
                self.state = .loaded(translations: self.translations)
            }
        } withCancel: { (error) in
            Logger.log(error,
                       metadata: [#file, #function, #line])
        }
    }
    
    private func signOut(_ viewRouter: ViewRouter) {
        ConversationArchiver.clearArchive()
        ContactArchiver.clearArchive()
        
        RuntimeStorage.store(false, as: .shouldReloadData)
        RuntimeStorage.store(0, as: .messageOffset)
        
        UserDefaults.standard.setValue(nil, forKey: "currentUserID")
        
        RuntimeStorage.remove(.currentUser)
        RuntimeStorage.remove(.currentUserID)
        
        RuntimeStorage.store(Locale.preferredLanguages[0].components(separatedBy: "-")[0], as: .languageCode)
        AKCore.shared.setLanguageCode(RuntimeStorage.languageCode!)
        
        viewRouter.currentPage = .initial
    }
    
    private func translateAndLoad(conversations: [Conversation],
                                  completion: @escaping() -> Void = { }) {
        let dataModel = PageViewDataModel(inputs: self.inputs)
        
        dataModel.translateStrings { (returnedTranslations,
                                      returnedException) in
            guard let translations = returnedTranslations else {
                let exception = returnedException ?? Exception(metadata: [#file, #function, #line])
                Logger.log(exception)
                
                self.state = .failed(exception)
                completion()
                return
            }
            
            self.translations = translations
            
            RuntimeStorage.currentUser?.openConversations = conversations
            
            self.state = .loaded(translations: translations/*,
                                                            conversations: conversations*/)
            completion()
        }
    }
    
    private func trashDatabase() {
        removeConversationsForAllUsers { exception in
            guard exception == nil else {
                let translateDescriptor = exception!.userFacingDescriptor == exception!.descriptor
                AKErrorAlert(error: exception!.asAkError(),
                             shouldTranslate: translateDescriptor ? [.all] : [.actions(indices: nil),
                                                                              .cancelButtonTitle]).present()
                return
            }
            
            let keys = ["Conversations", "Messages"]
            
            var exceptions = [Exception]()
            for (index, key) in keys.enumerated() {
                GeneralSerializer.setValue(onKey: "/all\(key)",
                                           withData: NSNull()) { returnedError in
                    if let error = returnedError {
                        exceptions.append(Exception(error, metadata: [#file, #function, #line]))
                    }
                }
                
                if index == keys.count - 1 {
                    guard exceptions.count == 0 else {
                        let translateDescriptor = exceptions.compiledException!.userFacingDescriptor != exceptions.compiledException!.descriptor
                        AKErrorAlert(error: exceptions.compiledException!.asAkError(),
                                     shouldTranslate: translateDescriptor ? [.all] : [.actions(indices: nil),
                                                                                      .cancelButtonTitle]).present()
                        return
                    }
                    
                    AKAlert(message: "Successfully trashed database.",
                            cancelButtonTitle: "OK").present { _ in
                        RuntimeStorage.currentUser?.openConversations = nil
                        ConversationArchiver.clearArchive()
                        self.load()
                    }
                }
            }
        }
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: - Array */
public extension Array where Element == String {
    var duplicates: [String]? {
        let duplicates = Array(Set(filter({ (s: String) in filter({ $0 == s }).count > 1})))
        return duplicates.isEmpty ? nil : duplicates
    }
}
