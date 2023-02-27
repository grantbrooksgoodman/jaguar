//
//  Localizer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 25/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public enum LocalizationCase: String /* Add pre-localized strings here. */ {
    case cancel
    case dismiss
    case done
    case multiple
    
    case contacts
    case copy
    case delete // unused
    
    case delivered
    case read
    case sending
    
    case holdToRetry
    case retryTranslation
    
    case invite
    case newMessage
    case search
    case to
    
    case messageReceived
    case myAccount
    
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday
    
    case noEmail
    case noInternetMessage
    case noInternetTitle
    
    case notSupported
    case sendFeedback
    case timedOut
    
    case speak
    case stopSpeaking
    
    case today
    case yesterday
    
    case viewAsAudio
    case viewOriginal
    case viewTranslation
    case viewTranscription
    
    case slideToCancel
    case holdDownToRecord
    case noSpeechDetected
    
    case settings
    
    var description: String {
        return rawValue.snakeCase()
    }
}

public struct LocalizedString {
    public static var cancel: String { Localizer.preLocalizedString(for: .cancel) ?? "Cancel" }
    public static var dismiss: String { Localizer.preLocalizedString(for: .dismiss) ?? "Dismiss" }
    public static var done: String { Localizer.preLocalizedString(for: .done) ?? "Done" }
    public static var multiple: String { Localizer.preLocalizedString(for: .multiple) ?? "Multiple" }
    
    public static var contacts: String { Localizer.preLocalizedString(for: .contacts) ?? "Contacts" }
    public static var copy: String { Localizer.preLocalizedString(for: .copy) ?? "Copy" }
    public static var delete: String { Localizer.preLocalizedString(for: .delete) ?? "Delete" }
    
    public static var delivered: String { Localizer.preLocalizedString(for: .delivered) ?? "Delivered" }
    public static var read: String { Localizer.preLocalizedString(for: .read) ?? "Read" }
    public static var sending: String { Localizer.preLocalizedString(for: .sending) ?? "Sending" }
    
    public static var holdToRetry: String { Localizer.preLocalizedString(for: .holdToRetry) ?? "⚠️ Hold down to retry translation" }
    public static var retryTranslation: String { Localizer.preLocalizedString(for: .retryTranslation) ?? "Retry Translation" }
    
    public static var invite: String { Localizer.preLocalizedString(for: .invite) ?? "Invite" }
    public static var newMessage: String { Localizer.preLocalizedString(for: .newMessage) ?? "New Message" }
    public static var search: String { Localizer.preLocalizedString(for: .search) ?? "Search" }
    public static var to: String { Localizer.preLocalizedString(for: .to) ?? "To:" }
    
    public static var messageReceived: String { Localizer.preLocalizedString(for: .messageReceived) ?? "Message Received" }
    public static var myAccount: String { Localizer.preLocalizedString(for: .myAccount) ?? "(Me)" }
    
    public static var monday: String { Localizer.preLocalizedString(for: .monday) ?? "Monday" }
    public static var tuesday: String { Localizer.preLocalizedString(for: .tuesday) ?? "Tuesday" }
    public static var wednesday: String { Localizer.preLocalizedString(for: .wednesday) ?? "Wednesday" }
    public static var thursday: String { Localizer.preLocalizedString(for: .thursday) ?? "Thursday" }
    public static var friday: String { Localizer.preLocalizedString(for: .friday) ?? "Friday" }
    public static var saturday: String { Localizer.preLocalizedString(for: .saturday) ?? "Saturday" }
    public static var sunday: String { Localizer.preLocalizedString(for: .sunday) ?? "Sunday" }
    
    public static var noEmail: String? { Localizer.preLocalizedString(for: .noEmail) }
    public static var noInternetMessage: String? { Localizer.preLocalizedString(for: .noInternetMessage) }
    public static var noInternetTitle: String? { Localizer.preLocalizedString(for: .noInternetTitle) }
    
    public static var notSupported: String? { Localizer.preLocalizedString(for: .notSupported) }
    public static var sendFeedback: String { Localizer.preLocalizedString(for: .sendFeedback) ?? "Send Feedback" }
    public static var timedOut: String? { Localizer.preLocalizedString(for: .timedOut) }
    
    public static var speak: String { Localizer.preLocalizedString(for: .speak) ?? "Speak" }
    public static var stopSpeaking: String { Localizer.preLocalizedString(for: .stopSpeaking) ?? "Stop Speaking" }
    
    public static var today: String { Localizer.preLocalizedString(for: .today) ?? "Today" }
    public static var yesterday: String { Localizer.preLocalizedString(for: .yesterday) ?? "Yesterday" }
    
    public static var viewAsAudio: String { Localizer.preLocalizedString(for: .viewAsAudio) ?? "View as Audio" }
    public static var viewOriginal: String { Localizer.preLocalizedString(for: .viewOriginal) ?? "View Original" }
    public static var viewTranslation: String { Localizer.preLocalizedString(for: .viewTranslation) ?? "View Translation" }
    public static var viewTranscription: String { Localizer.preLocalizedString(for: .viewTranscription) ?? "View Transcription" }
    
    public static var slideToCancel: String { Localizer.preLocalizedString(for: .slideToCancel) ?? "Slide to cancel" }
    public static var holdDownToRecord: String { Localizer.preLocalizedString(for: .holdDownToRecord) ?? "Hold down to record" }
    public static var noSpeechDetected: String { Localizer.preLocalizedString(for: .noSpeechDetected) ?? "No speech detected" }
    
    public static var settings: String { Localizer.preLocalizedString(for: .settings) ?? "Settings" }
}

public enum Localizer {
    
    //==================================================//
    
    /* MARK: - Public Methods */
    
    public static func preLocalizedString(for case: LocalizationCase,
                                          language code: String? = nil) -> String? {
        let language = code ?? (RuntimeStorage.languageCode ?? "en")
        
        guard let essentialLocalizations = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "EssentialLocalizations", ofType: "plist") ?? "") as? [String: [String: String]],
              let dictionary = essentialLocalizations[`case`.description] else { return nil }
        
        return dictionary[language]
    }
}
