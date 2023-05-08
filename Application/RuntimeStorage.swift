//
//  RuntimeStorage.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 05/10/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import SwiftUI
import UIKit

/* Third-party Frameworks */
import InputBarAccessoryView

public class StateProvider: ObservableObject {
    
    /* MARK: - Properties */
    
    public static let shared = StateProvider()
    
    // Custom
    @Published public var currentUserLacksVisibleConversations = false
    @Published public var developerModeEnabled = Build.developerModeEnabled
    @Published public var hasDisappeared = false
    @Published public var showNewChatPageForGrantedContactAccess = false
    @Published public var tappedDone = false
    @Published public var tappedSelectContactButton = false
    @Published public var wantsToInvite = false
    @Published public var showingInviteLanguagePicker = false
    @Published public var shouldDismissSettingsPage = false
}

public enum RuntimeStorage {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Enums
    public enum StoredItem: String {
        // MARK: AppDelegate
        case archivedLocalUserHashes
        case archivedServerUserHashes
        
        case callingCode
        case callingCodeDictionary
        case lookupTableDictionary
        
        case currentUser
        case currentUserID
        
        case languageCode
        case languageCodeDictionary
        case localizedLanguageCodeDictionary
        
        case overriddenLanguageCode
        case selectedRegionCode
        
        case pushToken
        case updatedPushToken
        
        case mismatchedHashes
        case acknowledgedAudioMessagesUnsupported
        
        case didResetForFirstRun
        case isFirstLaunchFromSetup
        
        // MARK: BuildInfoOverlayView
        case currentFile
        
        // MARK: ChatPageView
        case contactPairs
        case coordinator
        
        case currentMessageSlice
        case globalConversation
        
        case isPresentingChat
        case isSendingMessage
        
        case messageOffset
        case messagesVC
        
        case shouldReloadData
        case typingIndicator
        
        case invitationLanguageCode
        case wantsToInvite
        
        // MARK: ConversationsPageView
        case currentYOrigin
        case previousYOrigin
        
        // MARK: ConversationsPageViewModel
        case becameActive
        case conversationsPageViewModel
        case receivedNotification
        case shouldReloadForFirstConversation
        case shouldUpdateReadState
        
        // MARK: SceneDelegate
        case topWindow
        
        // MARK: SignInPageView
        case numberFromSignIn
        
        var description: String {
            return rawValue.snakeCase()
        }
    }
    
    // Other
    private static var storedItems = [String: Any]()
    
    //==================================================//
    
    /* MARK: - Public Methods */
    
    public static func remove(_ item: StoredItem) {
        storedItems[item.description] = nil
    }
    
    public static func retrieve(_ item: StoredItem) -> Any? {
        guard let object = storedItems[item.description] else { return nil }
        
        return object
    }
    
    public static func store(_ object: Any, as: StoredItem) {
        storedItems[`as`.description] = object
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private static func getLocalizedLanguageCodeDictionary() -> [String: String]? {
        guard let languageCode,
              let languageCodeDictionary else { return nil }
        
        let locale = Locale(identifier: languageCode)
        
        var localizedNames = [String: String]()
        for (code, name) in languageCodeDictionary {
            guard let localizedName = locale.localizedString(forLanguageCode: code) else {
                localizedNames[code] = name
                continue
            }
            
            let components = name.components(separatedBy: "(")
            guard components.count == 2 else {
                let suffix = localizedName.lowercased() == name.lowercased() ? "" : "(\(name))"
                localizedNames[code] = "\(localizedName.firstUppercase) \(suffix)"
                continue
            }
            
            let endonym = components[1]
            let suffix = localizedName.lowercased() == endonym.lowercased().dropSuffix() ? "" : "(\(endonym)"
            localizedNames[code] = "\(localizedName.firstUppercase) \(suffix)"
        }
        
        return localizedNames
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: RuntimeStorage */
public extension RuntimeStorage {
    // MARK: AppDelegate
    static var archivedLocalUserHashes: [String]? { get { retrieve(.archivedLocalUserHashes) as? [String] } }
    static var archivedServerUserHashes: [String]? { get { retrieve(.archivedServerUserHashes) as? [String] } }
    
    static var callingCode: String? { get { retrieve(.callingCode) as? String } } // Doesn't seem to be used
    static var callingCodeDictionary: [String: String]? { get { retrieve(.callingCodeDictionary) as? [String: String] } }
    static var lookupTableDictionary: [String: [String]]? { get { retrieve(.lookupTableDictionary) as? [String: [String]] } }
    
    static var currentUser: User? { get { retrieve(.currentUser) as? User } }
    static var currentUserID: String? { get { retrieve(.currentUserID) as? String } }
    
    static var languageCode: String? { get { guard let overridden = retrieve(.overriddenLanguageCode) as? String else { return retrieve(.languageCode) as? String }; return overridden } }
    static var languageCodeDictionary: [String: String]? { get { retrieve(.languageCodeDictionary) as? [String: String] } }
    static var localizedLanguageCodeDictionary: [String: String]? { get { getLocalizedLanguageCodeDictionary() } }
    
    static var pushToken: String? { get { retrieve(.pushToken) as? String } }
    static var updatedPushToken: Bool? { get { retrieve(.updatedPushToken) as? Bool } }
    
    static var selectedRegionCode: String? { get { retrieve(.selectedRegionCode) as? String } }
    static var mismatchedHashes: [String]? { get { retrieve(.mismatchedHashes) as? [String] } }
    static var acknowledgedAudioMessagesUnsupported: Bool? { get { retrieve(.acknowledgedAudioMessagesUnsupported) as? Bool } }
    
    static var didResetForFirstRun: Bool? { get { retrieve(.didResetForFirstRun) as? Bool } }
    static var isFirstLaunchFromSetup: Bool? { get { retrieve(.isFirstLaunchFromSetup) as? Bool } }
    
    // MARK: BuildInfoOverlayView
    static var currentFile: String? { get { retrieve(.currentFile) as? String } }
    
    // MARK: ChatPageView
    static var contactPairs: [ContactPair]? { get { retrieve(.contactPairs) as? [ContactPair] } }
    static var coordinator: ChatPageViewCoordinator? { get { retrieve(.coordinator) as? ChatPageViewCoordinator } }
    
    static var currentMessageSlice: [Message]? { get { retrieve(.currentMessageSlice) as? [Message] } }
    static var globalConversation: Conversation? { get { retrieve(.globalConversation) as? Conversation } }
    
    static var isPresentingChat: Bool? { get { retrieve(.isPresentingChat) as? Bool } }
    static var isSendingMessage: Bool? { get { retrieve(.isSendingMessage) as? Bool } }
    
    static var messageOffset: Int? { get { retrieve(.messageOffset) as? Int }  }
    static var messagesVC: ChatPageViewController? { get { retrieve(.messagesVC) as? ChatPageViewController } }
    
    static var shouldReloadData: Bool? { get { retrieve(.shouldReloadData) as? Bool } }
    static var typingIndicator: Bool? { get { retrieve(.typingIndicator) as? Bool } }
    
    static var invitationLanguageCode: String? { get { retrieve(.invitationLanguageCode) as? String } }
    static var wantsToInvite: Bool? { get { retrieve(.wantsToInvite) as? Bool } }
    
    // MARK: ConversationsPageView
    static var currentYOrigin: CGFloat? { get { retrieve(.currentYOrigin) as? CGFloat } }
    static var previousYOrigin: CGFloat? { get { retrieve(.previousYOrigin) as? CGFloat } }
    
    // MARK: ConversationsPageViewModel
    static var becameActive: Bool? { get { retrieve(.becameActive) as? Bool } }
#if !EXTENSION
    static var conversationsPageViewModel: ConversationsPageViewModel? { get { retrieve(.conversationsPageViewModel) as? ConversationsPageViewModel } }
#endif
    static var receivedNotification: Bool? { get { retrieve(.receivedNotification) as? Bool } }
    static var shouldReloadForFirstConversation: Bool? { get { retrieve(.shouldReloadForFirstConversation) as? Bool } }
    static var shouldUpdateReadState: Bool? { get { retrieve(.shouldUpdateReadState) as? Bool } }
    
    // MARK: SceneDelegate
    static var topWindow: UIWindow? { get { retrieve(.topWindow) as? UIWindow } }
    
    // MARK: SignInPageView
    static var numberFromSignIn: String? { get { retrieve(.numberFromSignIn) as? String } }
}

