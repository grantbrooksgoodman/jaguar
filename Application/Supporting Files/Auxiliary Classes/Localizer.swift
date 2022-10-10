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

/* MARK: - Enums */

public enum LocalizationCase: String /* Add pre-localized strings here. */ {
    case dismiss
    case noEmail
    
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday
    
    case newMessage
    case delivered
    case read
    case sending
    
    case noInternetMessage
    case noInternetTitle
    
    case notSupported
    case sendFeedback
    
    case today
    case yesterday
    
    var description: String {
        return rawValue.snakeCase()
    }
}

public enum Localizer {
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
    public static func preLocalizedString(for case: LocalizationCase,
                                          language code: String? = nil) -> String? {
        let language = code ?? RuntimeStorage.languageCode!
        
        guard let essentialLocalizations = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "EssentialLocalizations", ofType: "plist") ?? "") as? [String: [String: String]] else { return nil }
        
        guard let dictionary = essentialLocalizations[`case`.description] else { return nil }
        
        return dictionary[language]
    }
}
