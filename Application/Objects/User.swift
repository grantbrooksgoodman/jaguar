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
    
    //==================================================//
    
    /* MARK: - Constructor Function */
    
    public init(identifier: String,
                languageCode: String,
                openConversations: [String]?,
                phoneNumber: String) {
        self.identifier = identifier
        self.languageCode = languageCode
        self.openConversations = openConversations
        self.phoneNumber = phoneNumber
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    public func deSerializeConversations(completion: @escaping(_ conversations: [Conversation]?,
                                                               _ error: String?) -> Void) {
        if let openConversations = openConversations {
            if let DSOpenConversations = DSOpenConversations {
                completion(DSOpenConversations, nil)
            } else {
                ConversationSerializer().getConversations(withIdentifiers: openConversations) { (returnedConversations, errorDescriptor) in
                    if let conversations = returnedConversations {
                        //if a user has a conversation, that means they have a match already. it must.
                        self.DSOpenConversations = conversations
                        
                        completion(conversations, nil)
                    } else if let error = errorDescriptor {
                        completion(nil, error)
                    }
                }
            }
        } else {
            completion(nil, "No Conversations to deserialize.")
        }
    }
    
    public func formattedPhoneNumber() -> String {
        let phoneNumberKit = PhoneNumberKit()
        let numberFormats: [PhoneNumberFormat] = [.e164, .international, .national]
        var numberString = phoneNumber!
        
        var index = 0
        while index < numberFormats.count && !numberString.contains(" ") {
            do {
                let parsedPhoneNumber = try phoneNumberKit.parse(phoneNumber!)
                numberString = phoneNumberKit.format(parsedPhoneNumber, toType: numberFormats[index])
            } catch {
                log("Unable to format phone number with this method.",
                    verbose: true,
                    metadata: [#file, #function, #line])
            }
            
            index += 1
        }
        
        if !numberString.contains(" ") {
            log("Reverting to formatting phone number using partial formatter.",
                verbose: true,
                metadata: [#file, #function, #line])
            
            numberString = PartialFormatter().formatPartial(phoneNumber!)
            numberString = "+\(numberString)".replacingOccurrences(of: "(", with: " (").replacingOccurrences(of: "+ (", with: "+(")
        }
        
        return numberString
    }
    
    public func updateLastActiveDate() {
        GeneralSerializer.setValue(onKey: "/allUsers/\(identifier!)/lastActive",
                                   withData: secondaryDateFormatter.string(from: Date())) { (returnedError) in
            if let error = returnedError {
                log("Update last active date failed! \(errorInfo(error))",
                    metadata: [#file, #function, #line])
            }
        }
    }
}

//==================================================//

/* MARK: - Extensions */

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

