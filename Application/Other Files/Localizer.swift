//
//  Localizer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 25/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public enum LocalizationCase {
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
        switch self {
        case .dismiss:
            return "dismiss"
        case .followingUnable:
            return "following_unable"
        case .noInternetMessage:
            return "no_internet_message"
        case .noInternetTitle:
            return "no_internet_title"
        case .notSupportedMessage:
            return "not_supported"
        case .sendFeedback:
            return "send_feedback"
        case .unableMessage:
            return "unable_message"
        case .unableTitle:
            return "unable_title"
        case .newMessage:
            return "new_message"
        case .today:
            return "today"
        case .yesterday:
            return "yesterday"
        case .monday:
            return "monday"
        case .tuesday:
            return "tuesday"
        case .wednesday:
            return "wednesday"
        case .thursday:
            return "thursday"
        case .friday:
            return "friday"
        case .saturday:
            return "saturday"
        case .sunday:
            return "sunday"
        }
    }
}

public struct Localizer {
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
