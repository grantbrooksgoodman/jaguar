//
//  RuntimeStorage.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 05/10/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

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
        case previousLanguageCode
        
        case selectedContactPair
        
        case shouldUseRandomUser
        
        // MARK: SceneDelegate
        case topWindow
        
        // MARK: BuildInfoOverlayView
        case currentFile
        
        // MARK: ConversationsPageView
        case conversations
        
        // MARK: ChatPageView
        case currentMessageSlice
        case globalConversation
        case messageOffset
        case shouldReloadData
        case typingIndicator
        
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

/* MARK: StoreService */
public extension RuntimeStorage {
    // MARK: AppDelegate
    static var callingCode: String? { get { return retrieve(.callingCode) as? String } } // Doesn't seem to be used
    static var selectedRegionCode: String? { get { return retrieve(.selectedRegionCode) as? String } }
    
    static var callingCodeDictionary: [String: String]? { get { return retrieve(.callingCodeDictionary) as? [String: String] } }
    static var languageCodeDictionary: [String: String]? { get { return retrieve(.languageCodeDictionary) as? [String: String] } }
    
    static var currentUser: User? { get { return retrieve(.currentUser) as? User } }
    static var currentUserID: String? { get { return retrieve(.currentUserID) as? String } }
    
    static var languageCode: String? { get { return retrieve(.languageCode) as? String }}
    static var previousLanguageCode: String? { get { return retrieve(.previousLanguageCode) as? String }}
    
    static var selectedContactPair: ContactPair? { get { return retrieve(.selectedContactPair) as? ContactPair } }
    
    static var shouldUseRandomUser: Bool? { get { return retrieve(.shouldUseRandomUser) as? Bool } }
    
    // MARK: BuildInfoOverlayView
    static var currentFile: String? { get { return retrieve(.currentFile) as? String } }
    
    // MARK: ChatPageView
    static var currentMessageSlice: [Message]? { get { return retrieve(.currentMessageSlice) as? [Message] } }
    static var globalConversation: Conversation? { get { return retrieve(.globalConversation) as? Conversation } }
    static var messageOffset: Int? { get { return retrieve(.messageOffset) as? Int }  }
    static var shouldReloadData: Bool? { get { return retrieve(.shouldReloadData) as? Bool } }
    static var typingIndicator: Bool? { get { return retrieve(.typingIndicator) as? Bool } }
    
    // MARK: ConversationsPageView
    static var conversations: [Conversation]? { get { return retrieve(.conversations) as? [Conversation] } }
    
    // MARK: SceneDelegate
    static var topWindow: UIWindow? { get { return retrieve(.topWindow) as? UIWindow } }
}

