//
//  AnalyticsService.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 31/12/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

/* Third-party Frameworks */
#if !EXTENSION
import FirebaseAnalytics
#endif

public enum AnalyticsEvent: String {
    case accessChat
    case deleteConversation
    case sendMessage
    case viewAlternate
    
    case accessNewChatPage
    case createNewConversation
    case dismissNewChatPage
    case invite
    
    case clearCaches
    case logIn
    case logOut
    case signUp
    
    case openApp
    case closeApp
    case terminateApp
    
    var description: String {
        return rawValue.snakeCase()
    }
}

public struct AnalyticsService {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private static var hasLoggedLogInEvent = false
    
    //==================================================//
    
    /* MARK: - Event Logging */
    
    public static func logEvent(_ event: AnalyticsEvent,
                                with parameters: [String: Any]? = nil) {
        if event == .logIn,
           hasLoggedLogInEvent {
            return
        }
        
        let standardParams = standardParams()
        var injectedParams = parameters ?? [:]
        injectedParams.merge(standardParams, uniquingKeysWith: { _,_ in })
        
#if !EXTENSION
        Analytics.logEvent(event.description,
                           parameters: injectedParams.snakeCasedKeys())
#endif
        
        if event == .logIn {
            hasLoggedLogInEvent = true
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private static func standardParams() -> [String: Any] {
        var parameters = [String: Any]()
        
        if let currentUserID = RuntimeStorage.currentUserID {
            parameters["currentUserId"] = currentUserID
        }
        
        if let storedLanguageCode = RuntimeStorage.languageCode {
            parameters["storedLanguageCode"] = storedLanguageCode
        }
        
        if let userLanguageCode = RuntimeStorage.currentUser?.languageCode {
            parameters["userLanguageCode"] = userLanguageCode
        }
        
        if let currentFile = RuntimeStorage.currentFile,
           !currentFile.components(separatedBy: "/").isEmpty {
            guard let fileName = currentFile.components(separatedBy: "/").last else { return parameters }
            guard let trimmedFileName = fileName.components(separatedBy: ".").first else { return parameters }
            
            let snakeCaseFileName = trimmedFileName.firstLowercase.snakeCase()
            parameters["currentFile"] = snakeCaseFileName
        }
        
        return parameters
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: Dictionary */
extension Dictionary where Key == String, Value == Any {
    public func snakeCasedKeys() -> [String: Any] {
        var new = [String: Any]()
        
        for item in self {
            new[item.key.snakeCase()] = item.value
        }
        
        return new
    }
}
