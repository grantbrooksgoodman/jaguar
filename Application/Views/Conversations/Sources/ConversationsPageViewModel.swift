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
        case loaded(translations: [String: Translator.Translation],
                    conversations: [Conversation])
    }
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Booleans
    private var shouldReloadForGlobalStateChange: Bool { get { getShouldReloadForGlobalStateChange() } }
    private var shouldReloadForUpdatedHashes: Bool { get { getShouldReloadForUpdatedHashes() } }
    
    // Other
    public let inputs = ["messages": Translator.TranslationInput(ThemeService.currentTheme != AppThemes.default ? "Conversations" : "Messages")]
    
    @Published private(set) var state = State.idle
    private var translations: [String: Translator.Translation]!
    
    //==================================================//
    
    /* MARK: - Initializer Method */
    
    public func load(silent: Bool = false,
                     canShowOverlay: Bool = false,
                     completion: @escaping() -> Void = { }) {
        RuntimeStorage.store(self, as: .conversationsPageViewModel)
        state = silent ? state : .loading
        
        Core.ui.resetNavigationBarAppearance()
        
        guard let currentUserID = RuntimeStorage.currentUserID else {
            state = .failed(Exception("No current user ID!", metadata: [#file, #function, #line]))
            completion()
            return
        }
        
        addOverlayIfNeeded(silent: silent, canShowOverlay: canShowOverlay)
        respondToGlobalStateChange(silent)
        MetadataService.setKeys()
        
        instantiateCurrentUser(currentUserID) { user, exception in
            guard let user else {
                self.state = .failed(exception ?? Exception(metadata: [#file, #function, #line]))
                completion()
                return
            }
            
            RuntimeStorage.topWindow?.isUserInteractionEnabled = false
            
            self.retrieveConversations(for: user) { conversations, exception in
                guard let conversations else {
                    self.state = .failed(exception ?? Exception(metadata: [#file, #function, #line]))
                    RuntimeStorage.topWindow?.isUserInteractionEnabled = true
                    RuntimeStorage.topWindow?.removeOverlay()
                    completion()
                    return
                }
                
                StateProvider.shared.currentUserLacksVisibleConversations = conversations.visibleForCurrentUser.count == 0
                //                conversations.forEach { conversation in
                //                    self.setUpObserver(for: conversation)
                //                }
                
                RuntimeStorage.topWindow?.isUserInteractionEnabled = true
                self.translateAndLoad(conversations: conversations) {
                    self.requestNotificationPermissionIfNeeded { exception in
                        guard exception == nil else {
                            Logger.log(exception!, with: .errorAlert)
                            return
                        }
                        
                        Core.gcd.after(seconds: 2) { UpdateService.promptToUpdateIfNeeded() }
                    }
                    
                    RuntimeStorage.topWindow?.removeOverlay()
                    completion()
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Computed Property Getters */
    
    private func getShouldReloadForGlobalStateChange() -> Bool {
        let becameActive = RuntimeStorage.becameActive ?? false
        let receivedNotification = RuntimeStorage.receivedNotification!
        let shouldReloadForFirstOrNewConversation = RuntimeStorage.shouldReloadForFirstOrNewConversation!
        let shouldUpdateReadState = RuntimeStorage.shouldUpdateReadState!
        return becameActive || receivedNotification || shouldReloadForFirstOrNewConversation || shouldUpdateReadState
    }
    
    private func getShouldReloadForUpdatedHashes() -> Bool {
        guard let previousHashes = UserDefaults.standard.object(forKey: "previousHashes") as? [String],
              let currentHashes = RuntimeStorage.currentUser?.openConversations?.hashes(),
              previousHashes != currentHashes else { return false }
        return true
    }
    
    //==================================================//
    
    /* MARK: - Conversation Deletion */
    
    public func deleteConversation(_ conversation: Conversation) {
        guard let currentUser = RuntimeStorage.currentUser else { return }
        
        guard let otherUser = conversation.otherUser else {
            conversation.setOtherUser { exception in
                guard exception == nil else {
                    Logger.log(exception!, with: .errorAlert)
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
            
            RuntimeStorage.topWindow?.isUserInteractionEnabled = false
            ConversationSerializer.shared.deleteConversation(withIdentifier: conversation.identifier.key!) { exception in
                if let exception {
                    Logger.log(exception, with: .errorAlert)
                }
                
                currentUser.deSerializeConversations { _, exception in
                    RuntimeStorage.topWindow?.isUserInteractionEnabled = true
                    guard let exception else {
                        self.load()
                        return
                    }
                    
                    Logger.log(exception, with: .errorAlert)
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Data Fetching */
    
    private func instantiateCurrentUser(_ id: String,
                                        completion: @escaping(_ user: User?,
                                                              _ exception: Exception?) -> Void) {
        func updatePushTokensIfNeeded(for user: User) {
            guard !RuntimeStorage.updatedPushToken! else { return }
            
            user.updatePushTokens { exception in
                guard let exception else {
                    RuntimeStorage.store(true, as: .updatedPushToken)
                    return
                }
                
                Logger.log(exception, verbose: true)
            }
        }
        
        UserSerializer.shared.getUser(withIdentifier: id) { user, exception in
            guard let user else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            UserDefaults.standard.setValue(user.identifier, forKey: "currentUserID")
            RuntimeStorage.store(user, as: .currentUser)
            
            RuntimeStorage.store(user.languageCode!, as: .languageCode)
            AKCore.shared.setLanguageCode(user.languageCode)
            
            updatePushTokensIfNeeded(for: user)
            completion(user, nil)
        }
    }
    
    private func retrieveConversations(for user: User,
                                       completion: @escaping(_ conversations: [Conversation]?,
                                                             _ exception: Exception?) -> Void) {
        user.deSerializeConversations { conversations, exception in
            guard let conversations else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(conversations, nil)
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
    
    //==================================================//
    
    /* MARK: - Global State Changes */
    
    private func resetGlobalStateChangeVariables() {
        RuntimeStorage.store(false, as: .receivedNotification)
        RuntimeStorage.store(false, as: .shouldReloadForFirstOrNewConversation)
        RuntimeStorage.store(false, as: .shouldUpdateReadState)
        
        guard RuntimeStorage.becameActive != nil else { return }
        RuntimeStorage.store(false, as: .becameActive)
    }
    
    private func respondToGlobalStateChange(_ silent: Bool) {
        defer { RuntimeStorage.remove(.globalConversation) }
        guard shouldReloadForGlobalStateChange else { return }
        defer { resetGlobalStateChangeVariables() }
        
        guard silent else { return }
        
        guard let globalConversationKey = RuntimeStorage.globalConversation?.identifier.key else {
            ConversationArchiver.clearArchive()
            return
        }
        
        ConversationArchiver.removeFromArchive(withKey: globalConversationKey)
        RuntimeStorage.remove(.globalConversation)
        resetGlobalStateChangeVariables()
    }
    
    //==================================================//
    
    /* MARK: - Miscellaneous Methods */
    
    private func addOverlayIfNeeded(silent: Bool, canShowOverlay: Bool) {
        guard silent && canShowOverlay else { return }
        Core.gcd.after(milliseconds: 200) {
            guard let topWindow = RuntimeStorage.topWindow,
                  !topWindow.isUserInteractionEnabled,
                  topWindow.subview(for: "OVERLAY_VIEW") == nil else {
                RuntimeStorage.topWindow?.removeOverlay()
                return
            }
            
            topWindow.addOverlay(alpha: 0.85, color: .black, showsActivityIndicator: true)
        }
    }
    
    public func reloadIfNeeded() {
        StateProvider.shared.hasDisappeared = false
        
        guard Build.isOnline,
              !RuntimeStorage.isPresentingChat! else { return }
        
        guard (shouldReloadForGlobalStateChange || shouldReloadForUpdatedHashes),
              RuntimeStorage.currentFile!.hasSuffix("ConversationsPageView.swift") else {
            RuntimeStorage.remove(.globalConversation)
            return
        }
        
        if shouldReloadForUpdatedHashes {
            if let currentHashes = RuntimeStorage.currentUser?.openConversations?.hashes() {
                UserDefaults.standard.set(currentHashes, forKey: "previousHashes")
            }
        }
        
        load(silent: true, canShowOverlay: RuntimeStorage.becameActive ?? false)
    }
    
    private func requestNotificationPermissionIfNeeded(completion: @escaping(_ exception: Exception?) -> Void) {
        PermissionService.getNotificationPermissionStatus { status in
            guard status == .unknown else {
                completion(nil)
                return
            }
            
            Core.gcd.after(seconds: 2) {
                PermissionService.requestPermission(for: .notifications) { status, exception in
                    guard status == .granted else {
                        guard let exception else {
                            PermissionService.presentCTA(for: .notifications) { completion(nil) }
                            return
                        }
                        
                        completion(exception)
                        return
                    }
                }
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
                conversation.messages = conversation.messages.filteredAndSorted
                RuntimeStorage.currentUser?.openConversations = RuntimeStorage.currentUser?.openConversations?.unique()
                
                self.state = .loaded(translations: self.translations,
                                     conversations: RuntimeStorage.currentUser?.openConversations ?? [])
            }
        } withCancel: { (error) in
            Logger.log(error,
                       metadata: [#file, #function, #line])
        }
    }
}
