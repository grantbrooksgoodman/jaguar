//
//  User.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 07/03/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import UIKit

/* Third-party Frameworks */
import PhoneNumberKit

public class User {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    //Arrays
    public var openConversations: [String]?
    private var DSOpenConversations: [Conversation]?
    
    //Strings
    public var identifier: String!
    public var languageCode: String!
    public var phoneNumber: String!
    public var region: String!
    
    private(set) var isUpdatingConversations = false
    
    //==================================================//
    
    /* MARK: - Constructor Function */
    
    public init(identifier: String,
                languageCode: String,
                openConversations: [String]?,
                phoneNumber: String,
                region: String) {
        self.identifier = identifier
        self.languageCode = languageCode
        self.openConversations = openConversations
        self.phoneNumber = phoneNumber
        self.region = region
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    public func update(isTyping: Bool,
                       inConversationWithID: String,
                       completion: @escaping (_ errorDescriptor: String?) -> Void = { _ in }) {
        GeneralSerializer.getValues(atPath: "/allConversations/\(inConversationWithID)") { (returnedValues, errorDescriptor) in
            guard let values = returnedValues as? [String: Any] else {
                let error = errorDescriptor ?? "An unknown error occurred."
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                completion(error)
                return
            }
            
            guard let participants = values["participants"] as? [String] else {
                completion("Couldn't deserialize participants.")
                return
            }
            
            let otherUserID = participants.filter({$0.components(separatedBy: " | ")[0] != self.identifier! }).first!
            let updatedParticipants = ["\(self.identifier!) | \(isTyping)", otherUserID]
            
            GeneralSerializer.setValue(onKey: "/allConversations/\(inConversationWithID)/participants",
                                       withData: updatedParticipants) { (returnedError) in
                guard let error = returnedError else {
                    completion(nil)
                    return
                }
                
                completion(Logger.errorInfo(error))
            }
        }
    }
    
    public func updateConversationData(completion: @escaping(_ returnedConversations: [Conversation]?,
                                                             _ errorDescriptor: String?) -> Void = { _,_  in }) {
        guard let openConversations = openConversations else {
            completion([], nil)
            return
        }
        
        guard openConversations != [] else {
            completion([], nil)
            return
        }
        
        isUpdatingConversations = true
        
        deSerializeConversations { (returnedConversations,
                                    errorDescriptor) in
            guard let conversations = returnedConversations else {
                completion(nil, errorDescriptor ?? "An unknown error occurred.")
                
                return
            }
            
            let dispatchGroup = DispatchGroup()
            var errors = [String]()
            
            for conversation in conversations {
                dispatchGroup.enter()
                
                conversation.setOtherUser { (errorDescriptor) in
                    if let error = errorDescriptor {
                        errors.append(error)
                    }
                    
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                self.isUpdatingConversations = false
                completion(conversations, errors.isEmpty ? nil : errors.joined(separator: "\n"))
            }
        }
    }
    
    public func deSerializeConversations(completion: @escaping(_ conversations: [Conversation]?,
                                                               _ error: String?) -> Void) {
        var conversations = openConversations ?? []
        
        GeneralSerializer.getValues(atPath: "/allUsers/\(identifier!)/openConversations") { (returnedConversations, errorDescriptor) in
            
            guard let updatedConversations = returnedConversations as? [String] else {
                let error = errorDescriptor ?? "An unknown error occurred."
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                completion(nil, error)
                return
            }
            
            conversations = updatedConversations
            
            if conversations == self.openConversations,
               let DSOpenConversations = self.DSOpenConversations {
                completion(DSOpenConversations, nil)
            } else {
                ConversationSerializer().getConversations(withIdentifiers: conversations) { (returnedConversations, errorDescriptor) in
                    guard let conversations = returnedConversations else {
                        let error = errorDescriptor ?? "An unknown error occurred."
                        
                        Logger.log(error,
                                   metadata: [#file, #function, #line])
                        completion(nil, error)
                        return
                    }
                    
                    self.DSOpenConversations = conversations
                    completion(conversations, nil)
                }
            }
        }
    }
    
    public func updateLastActiveDate() {
        GeneralSerializer.setValue(onKey: "/allUsers/\(identifier!)/lastActive",
                                   withData: secondaryDateFormatter.string(from: Date())) { (returnedError) in
            if let error = returnedError {
                Logger.log("Update last active date failed! \(Logger.errorInfo(error))",
                           metadata: [#file, #function, #line])
            }
        }
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: Sequence */
extension Sequence where Iterator.Element == String {
    func containsAny(in array: [String]) -> Bool {
        for individualString in array {
            if contains(individualString) {
                return true
            }
        }
        
        return false
    }
    
    func lowercasedElements() -> [String] {
        var finalArray: [String]! = []
        
        for individualString in self {
            finalArray.append(individualString.lowercased())
        }
        
        return finalArray
    }
    
    func removingSpecialCharacters() -> [String] {
        let acceptableCharacters = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890")
        
        var finalArray: [String]! = []
        
        for individualString in self {
            finalArray.append(individualString.filter { acceptableCharacters.contains($0) })
        }
        
        return finalArray
    }
}

extension PhoneNumberFormat {
    func asString() -> String {
        switch self {
        case .e164:
            return "E164"
        case .international:
            return "International"
        case .national:
            return "National"
        }
    }
}

/* MARK: String */
extension String {
    func callingCodeFormatted(region: String) -> String {
        let phoneNumberKit = PhoneNumberKit()
        let callingCode = callingCodeDictionary[region] ?? ""
        
        let mutableSelf = self
        let digits = mutableSelf.digits
        let nationalNumber = digits.dropPrefix(callingCode.count)
        
        var formattedNumber = "\(nationalNumber)"
        
        do {
            let parsed = try phoneNumberKit.parse("\(nationalNumber)", withRegion: region)
            
            formattedNumber = phoneNumberKit.format(parsed, toType: .international)
            formattedNumber = formattedNumber.removingOccurrences(of: ["+"])
        } catch {
            //            Logger.log("Couldn't format number to international.",
            //                verbose: true,
            //                metadata: [#file, #function, #line])
        }
        
        if !formattedNumber.contains(" ") || (formattedNumber.characterArray.count(of: "-") == 2 &&
                                                formattedNumber.digits.count == 11) {
            
            formattedNumber = PartialFormatter(phoneNumberKit: PhoneNumberKit(),
                                               defaultRegion: region,
                                               withPrefix: true,
                                               maxDigits: nil).formatPartial(nationalNumber)
        }
        
        return "+\(callingCode) \(formattedNumber)".replacingOccurrences(of: "1(", with: "(")
    }
    
    func formattedPhoneNumber(region: String) -> String {
        let phoneNumberKit = PhoneNumberKit()
        let callingCode = callingCodeDictionary[region]!
        
        let mutableSelf = self
        let digits = mutableSelf.digits
        
        var formattedNumber = "\(callingCode)\(digits)"
        
        do {
            let parsed = try phoneNumberKit.parse("\(digits)", withRegion: region)
            
            formattedNumber = phoneNumberKit.format(parsed, toType: .international)
            formattedNumber = formattedNumber.removingOccurrences(of: ["+"])
        } catch {
            //            Logger.log("Couldn't format number to international.",
            //                verbose: true,
            //                metadata: [#file, #function, #line])
        }
        
        if !formattedNumber.contains(" ") {
            formattedNumber = PartialFormatter(phoneNumberKit: PhoneNumberKit(),
                                               defaultRegion: region,
                                               withPrefix: true,
                                               maxDigits: nil).formatPartial(digits)
        }
        
        if formattedNumber.characterArray.count(of: "-") == 2 &&
            formattedNumber.digits.count == 11 {
            
            formattedNumber = "\(PartialFormatter().formatPartial(self))"
        }
        
        return formattedNumber.hasPrefix("\(callingCode) ") ? formattedNumber.dropPrefix(callingCode.count + 1) : formattedNumber
    }
}

