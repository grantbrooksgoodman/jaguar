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
    case cancel
    case contacts
    case done
    case invite
    case search
    case to
    
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
    
    case timedOut
    
    case viewOriginal
    case viewTranslation
    
    case delete
    
    var description: String {
        return rawValue.snakeCase()
    }
}

public struct LocalizedString {
    public static var cancel: String {
        return Localizer.preLocalizedString(for: .cancel) ?? "Cancel"
    }
    
    public static var contacts: String {
        return Localizer.preLocalizedString(for: .contacts) ?? "Contacts"
    }
    
    public static var done: String {
        return Localizer.preLocalizedString(for: .done) ?? "Done"
    }
    
    public static var invite: String {
        return Localizer.preLocalizedString(for: .invite) ?? "Invite"
    }
    
    public static var search: String {
        return Localizer.preLocalizedString(for: .search) ?? "Search"
    }
    
    public static var to: String {
        return Localizer.preLocalizedString(for: .to) ?? "To:"
    }
    
    public static var dismiss: String {
        return Localizer.preLocalizedString(for: .dismiss) ?? "Dismiss"
    }
    
    public static var noEmail: String? {
        return Localizer.preLocalizedString(for: .noEmail)
    }
    
    public static var monday: String {
        return Localizer.preLocalizedString(for: .monday) ?? "Monday"
    }
    
    public static var tuesday: String {
        return Localizer.preLocalizedString(for: .tuesday) ?? "Tuesday"
    }
    
    public static var wednesday: String {
        return Localizer.preLocalizedString(for: .wednesday) ?? "Wednesday"
    }
    
    public static var thursday: String {
        return Localizer.preLocalizedString(for: .thursday) ?? "Thursday"
    }
    
    public static var friday: String {
        return Localizer.preLocalizedString(for: .friday) ?? "Friday"
    }
    
    public static var saturday: String {
        return Localizer.preLocalizedString(for: .saturday) ?? "Saturday"
    }
    
    public static var sunday: String {
        return Localizer.preLocalizedString(for: .sunday) ?? "Sunday"
    }
    
    public static var newMessage: String {
        return Localizer.preLocalizedString(for: .newMessage) ?? "Sunday"
    }
    
    public static var delivered: String {
        return Localizer.preLocalizedString(for: .delivered) ?? "Delivered"
    }
    
    public static var read: String {
        return Localizer.preLocalizedString(for: .read) ?? "Read"
    }
    
    public static var sending: String {
        return Localizer.preLocalizedString(for: .sending) ?? "Sending"
    }
    
    public static var noInternetMessage: String? {
        return Localizer.preLocalizedString(for: .noInternetMessage)
    }
    
    public static var noInternetTitle: String? {
        return Localizer.preLocalizedString(for: .noInternetTitle)
    }
    
    public static var notSupported: String? {
        return Localizer.preLocalizedString(for: .notSupported)
    }
    
    public static var sendFeedback: String {
        return Localizer.preLocalizedString(for: .sendFeedback) ?? "Send Feedback"
    }
    
    public static var today: String {
        return Localizer.preLocalizedString(for: .today) ?? "Today"
    }
    
    public static var yesterday: String {
        return Localizer.preLocalizedString(for: .yesterday) ?? "Yesterday"
    }
    
    public static var timedOut: String? {
        return Localizer.preLocalizedString(for: .timedOut)
    }
    
    public static var viewOriginal: String {
        return Localizer.preLocalizedString(for: .viewOriginal) ?? "View Original"
    }
    
    public static var viewTranslation: String {
        return Localizer.preLocalizedString(for: .viewTranslation) ?? "View Translation"
    }
    
    public static var delete: String {
        return Localizer.preLocalizedString(for: .delete) ?? "Delete"
    }
}

public enum Localizer {
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
    public static func preLocalizedString(for case: LocalizationCase,
                                          language code: String? = nil) -> String? {
        let language = code ?? RuntimeStorage.languageCode!
        
        guard let essentialLocalizations = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "EssentialLocalizations", ofType: "plist") ?? "") as? [String: [String: String]],
              let dictionary = essentialLocalizations[`case`.description] else { return nil }
        
        return dictionary[language]
    }
}
