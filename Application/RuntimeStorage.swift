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

public class StateProvider: ObservableObject {
    
    /* MARK: - Properties */
    
    public static let shared = StateProvider()
    
    // Custom
    @Published public var hasDisappeared = false
    
    @Published public var tappedSelectContactButton = false
    @Published public var tappedDone = false
}

public enum RuntimeStorage {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Enums
    public enum StoredItem: String {
        // MARK: AppDelegate
        case callingCode
        case selectedRegionCode
        
        case callingCodeDictionary
        case languageCodeDictionary
        
        case currentUser
        case currentUserID
        
        case languageCode
        
        case shouldUseRandomUser
        case archivedLocalUserHashes
        case archivedServerUserHashes
        
        // MARK: SceneDelegate
        case topWindow
        
        // MARK: BuildInfoOverlayView
        case currentFile
        
        // MARK: ConversationsPageViewModel
        case previousConversations
        
        // MARK: ChatPageView
        case currentMessageSlice
        case globalConversation
        
        case isSendingMessage
        case messageOffset
        case messagesVC
        
        case shouldReloadData
        case typingIndicator
        case wantsToInvite
        
        case isPresentingChat
        
        // MARK: UINavigationBarAppearance
        case navigationBarStandardAppearance
        case navgationBarScrollEdgeAppearance
        
        var description: String {
            return rawValue.snakeCase()
        }
    }
    
    // Other
    private static var storedItems = [String: Any]()
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
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
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: RuntimeStorage */
public extension RuntimeStorage {
    // MARK: AppDelegate
    static var callingCode: String? { get { return retrieve(.callingCode) as? String } } // Doesn't seem to be used
    static var selectedRegionCode: String? { get { return retrieve(.selectedRegionCode) as? String } }
    
    static var callingCodeDictionary: [String: String]? { get { return retrieve(.callingCodeDictionary) as? [String: String] } }
    static var languageCodeDictionary: [String: String]? { get { return retrieve(.languageCodeDictionary) as? [String: String] } }
    
    static var currentUser: User? { get { return retrieve(.currentUser) as? User } }
    static var currentUserID: String? { get { return retrieve(.currentUserID) as? String } }
    
    static var languageCode: String? { get { return retrieve(.languageCode) as? String } }
    
    static var shouldUseRandomUser: Bool? { get { return retrieve(.shouldUseRandomUser) as? Bool } }
    static var archivedLocalUserHashes: [String]? { get { return retrieve(.archivedLocalUserHashes) as? [String] } }
    static var archivedServerUserHashes: [String]? { get { return retrieve(.archivedServerUserHashes) as? [String] } }
    
    // MARK: BuildInfoOverlayView
    static var currentFile: String? { get { return retrieve(.currentFile) as? String } }
    
    // MARK: ChatPageView
    static var currentMessageSlice: [Message]? { get { return retrieve(.currentMessageSlice) as? [Message] } }
    static var globalConversation: Conversation? { get { return retrieve(.globalConversation) as? Conversation } }
    
    static var isSendingMessage: Bool? { get { return retrieve(.isSendingMessage) as? Bool } }
    static var messageOffset: Int? { get { return retrieve(.messageOffset) as? Int }  }
    static var messagesVC: ChatPageViewController? { get { return retrieve(.messagesVC) as? ChatPageViewController } }
    
    static var shouldReloadData: Bool? { get { return retrieve(.shouldReloadData) as? Bool } }
    static var typingIndicator: Bool? { get { return retrieve(.typingIndicator) as? Bool } }
    static var wantsToInvite: Bool? { get { return retrieve(.wantsToInvite) as? Bool } }
    
    static var isPresentingChat: Bool? { get { return retrieve(.isPresentingChat) as? Bool } }
    
    // MARK: ConversationsPageViewModel
    static var previousConversations: [Conversation]? { get { return retrieve(.previousConversations) as? [Conversation] } }
    
    // MARK: SceneDelegate
    static var topWindow: UIWindow? { get { return retrieve(.topWindow) as? UIWindow } }
    
    // MARK: UINavigationBar
    static var navigationBarStandardAppearance: UINavigationBarAppearance? { get { return retrieve(.navigationBarStandardAppearance) as? UINavigationBarAppearance } }
    static var navgationBarScrollEdgeAppearance: UINavigationBarAppearance? { get { return retrieve(.navgationBarScrollEdgeAppearance) as? UINavigationBarAppearance } }
}

