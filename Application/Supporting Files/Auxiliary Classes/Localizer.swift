//
//  Localizer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 25/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

//==================================================//

/* MARK: - Enumerated Type Declarations */

public enum LocalizationCase: String /* Add pre-localized strings here. */ {
    case dismiss
    case followingUnable
    
    case noInternetMessage
    case noInternetTitle
    
    case notSupportedMessage
    case sendFeedback
    
    case unableMessage
    case unableTitle
    
    case newMessage
    
    case today
    case yesterday
    
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday
    
    var description: String {
        return rawValue.snakeCase()
    }
}

public struct Localizer {
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
    public static func preLocalizedString(for case: LocalizationCase,
                                          language code: String? = nil) -> String? {
        let language = code ?? languageCode
        
        guard let essentialLocalizations = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "EssentialLocalizations", ofType: "plist") ?? "") as? [String: [String: String]] else {
            return nil
        }
        
        guard let dictionary = essentialLocalizations[`case`.description] else {
            return nil
        }
        
        return dictionary[language]
    }
}
