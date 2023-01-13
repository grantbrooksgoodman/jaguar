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

import FirebaseAnalytics

public class ConversationsPageViewModel: ObservableObject {
    
    //==================================================//
    
    /* MARK: - Enums */
    
    public enum State {
        case idle
        case loading
        case failed(Exception)
        case loaded(translations: [String: Translator.Translation],
                    conversations: [Conversation])
    }
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public let inputs = ["done": Translator.TranslationInput("Done", alternate: "Finish"),
                         "messages": Translator.TranslationInput("Messages")]
    
    @Published private(set) var state = State.idle
    private var translations: [String: Translator.Translation]!
    
    //==================================================//
    
    /* MARK: - Initializer Method */
    
    public func load(silent: Bool? = nil,
                     completion: @escaping() -> Void = { }) {
        RuntimeStorage.store(self, as: .conversationsPageViewModel)
        
        let silent = silent ?? false
        if !silent {
            state = .loading
        }
        
        Core.ui.resetNavigationBarAppearance()
        
        guard let currentUserID = RuntimeStorage.currentUserID else {
            state = .failed(Exception("No current user ID!",
                                      metadata: [#file, #function, #line]))
            completion()
            return
        }
        
        //        ContactService.clearCache()
        
        if RuntimeStorage.shouldUpdateReadState! ||
        /*RuntimeStorage.receivedNotification! ||*/
        (RuntimeStorage.becameActive ?? false) {
            if (RuntimeStorage.becameActive ?? false) {
                print("reloading because became active")
            }
            
            if silent {
                ConversationArchiver.clearArchive()
            }
            
            RuntimeStorage.store(false, as: .shouldUpdateReadState)
            RuntimeStorage.store(false, as: .receivedNotification)
            if RuntimeStorage.becameActive != nil {
                RuntimeStorage.store(false, as: .becameActive)
            }
        }
        
        setPushApiKey()
        
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
                
                if !RuntimeStorage.updatedPushToken! {
                    user.updatePushTokens { exception in
                        guard let exception else {
                            Logger.log("Successfully updated push tokens!",
                                       verbose: true,
                                       metadata: [#file, #function, #line])
                            RuntimeStorage.store(true, as: .updatedPushToken)
                            
                            return
                        }
                        
                        Logger.log(exception,
                                   verbose: true)
                    }
                }
                
                guard !ContactArchiver.contactArchive.isEmpty else {
                    guard !silent else {
                        self.translateAndLoad(conversations: conversations) { completion() }
                        return
                    }
                    
                    ContactService.loadContacts { contactPairs, exception in
                        guard contactPairs != nil else {
                            self.translateAndLoad(conversations: conversations) {
                                Core.gcd.after(seconds: 2) {
                                    Logger.log(exception ?? Exception(metadata: [#file, #function, #line]))
                                }
                                
                                completion()
                            }
                            
                            return
                        }
                        
                        self.translateAndLoad(conversations: conversations) { completion() }
                    }
                    
                    return
                }
                
                self.translateAndLoad(conversations: conversations) { completion() }
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
    
    public func deleteConversation(_ conversation: Conversation) {
        guard let currentUser = RuntimeStorage.currentUser else { return }
        
        guard let otherUser = conversation.otherUser else {
            conversation.setOtherUser { exception in
                guard exception == nil else {
                    Logger.log(exception!,
                               with: .errorAlert)
                    return
                }
                
                self.deleteConversation(conversation)
            }
            
            return
        }
        
        let actionSheet = AKActionSheet(title: otherUser.cellTitle,
                                        message: "Are you sure you'd like to delete this conversation?\nThis operation cannot be undone.",
                                        actions: [AKAction(title: "Delete", style: .destructive)],
                                        shouldTranslate: [.message, .actions(indices: nil), .cancelButtonTitle],
                                        networkDependent: true)
        
        actionSheet.present { (actionID) in
            guard actionID == actionSheet.actions[0].identifier else { return }
            
            AnalyticsService.logEvent(.deleteConversation,
                                      with: ["conversationIdKey": conversation.identifier.key!])
            
            ConversationSerializer.shared.deleteConversation(withIdentifier: conversation.identifier.key!) { (exception) in
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
    
    //==================================================//
    
    /* MARK: - Operation Confirmation */
    
    public func confirmClearCaches() {
        let alert = AKConfirmationAlert(title: "Clear Caches",
                                        message: "Are you sure you'd like to clear all caches?\n\nThis may fix some issues, but can also temporarily slow down the app while indexes rebuild.\n\nYou will need to restart the app for this to take effect.",
                                        confirmationStyle: .destructivePreferred)
        alert.present { didConfirm in
            if didConfirm == 1 {
                self.clearCaches()
            }
        }
    }
    
    public func confirmSignOut(_ viewRouter: ViewRouter) {
        AKConfirmationAlert(title: "Log Out",
                            message: "Are you sure you would like to log out?",
                            confirmationStyle: .preferred).present { didConfirm in
            if didConfirm == 1 {
                self.signOut(viewRouter)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Preference Actions */
    
    private func clearCaches() {
        ContactArchiver.clearArchive()
        ConversationArchiver.clearArchive()
        TranslationArchiver.clearArchive()
        
        AnalyticsService.logEvent(.clearCaches)
        
        UserDefaults.standard.set(nil, forKey: "archivedLocalUserHashes")
        UserDefaults.standard.set(nil, forKey: "archivedServerUserHashes")
        
        AKAlert(message: "Caches have been cleared. You must now restart the app.",
                actions: [AKAction(title: "Exit", style: .destructivePreferred)],
                showsCancelButton: false).present { _ in
            fatalError()
        }
    }
    
    public func overrideLanguageCode() {
        guard !AKCore.shared.languageCodeIsLocked else {
            RuntimeStorage.remove(.overriddenLanguageCode)
            AKCore.shared.unlockLanguageCode(andSetTo: RuntimeStorage.languageCode)
            
            guard let currentUser = RuntimeStorage.currentUser else { return }
            let languageCode = currentUser.languageCode!
            let languageName = languageCode.languageName ?? languageCode.uppercased()
            Core.hud.showSuccess(text: "Set to \(languageName)")
            
            return
        }
        
        RuntimeStorage.store("en", as: .overriddenLanguageCode)
        AKCore.shared.lockLanguageCode(to: "en")
        
        Core.hud.showSuccess(text: "Set to English")
    }
    
    private func signOut(_ viewRouter: ViewRouter) {
        AnalyticsService.logEvent(.logOut)
        
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
    
    //==================================================//
    
    /* MARK: - Miscellaneous Methods */
    
    public func reloadIfNeeded() {
        StateProvider.shared.hasDisappeared = false
        
        guard !RuntimeStorage.isPresentingChat! else { return }
        
        guard let previousHashes = UserDefaults.standard.object(forKey: "previousHashes") as? [String],
              let currentHashes = RuntimeStorage.currentUser?.openConversations?.hashes(),
              (previousHashes != currentHashes) || RuntimeStorage.shouldUpdateReadState! || RuntimeStorage.receivedNotification! || (RuntimeStorage.becameActive ?? false) else { return }
        
        UserDefaults.standard.set(currentHashes, forKey: "previousHashes")
        
        guard RuntimeStorage.currentFile!.hasSuffix("ConversationsPageView.swift") else { return }
        
        load(silent: true)
    }
    
    private func setPushApiKey(completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        guard RuntimeStorage.pushApiKey == nil else {
            completion(nil)
            return
        }
        
        if let pushApiKey = UserDefaults.standard.value(forKey: "pushApiKey") as? String {
            RuntimeStorage.store(pushApiKey, as: .pushApiKey)
            completion(nil)
        } else {
            GeneralSerializer.getPushApiKey { key, exception in
                guard let key else {
                    completion(exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                RuntimeStorage.store(key, as: .pushApiKey)
                UserDefaults.standard.set(RuntimeStorage.pushApiKey!, forKey: "pushApiKey")
                completion(nil)
            }
        }
    }
    
    private func setUpObserver(for conversation: Conversation) {
        let pathPrefix = "/\(GeneralSerializer.environment.shortString)/conversations/"
        Database.database().reference().child("\(pathPrefix)\(conversation.identifier!.key!)").observe(.childChanged) { (returnedSnapshot) in
            guard returnedSnapshot.key == "messages",
                  let messageIdentifiers = returnedSnapshot.value as? [String],
                  let newMessageID = messageIdentifiers.last else { return }
            
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
                
                self.state = .loaded(translations: self.translations,
                                     conversations: RuntimeStorage.currentUser?.openConversations ?? [])
            }
        } withCancel: { (error) in
            Logger.log(error,
                       metadata: [#file, #function, #line])
        }
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
            
#if !EXTENSION
            UIApplication.shared.applicationIconBadgeNumber = RuntimeStorage.currentUser!.badgeNumber
#endif
            
            self.state = .loaded(translations: translations,
                                 conversations: conversations.sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate }))
            
            completion()
        }
    }
}
