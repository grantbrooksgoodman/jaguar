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

public class User: Codable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Arrays
    public var conversationIDs: [ConversationID]?
    public var openConversations: [Conversation]? {
        didSet {
            openConversations = openConversations?.uniquedByIdentifiers().sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate })
            conversationIDs = openConversations?.identifiers()
        }
    }
    
    // Strings
    public var callingCode: String!
    public var identifier: String!
    public var languageCode: String!
    public var phoneNumber: String!
    public var region: String!
    
    // Other
    private(set) var isUpdatingConversations = false
    
    //==================================================//
    
    /* MARK: - Constructor Function */
    
    public init(identifier: String,
                callingCode: String,
                languageCode: String,
                conversationIDs: [ConversationID]?,
                phoneNumber: String,
                region: String) {
        self.identifier = identifier
        self.callingCode = callingCode
        self.languageCode = languageCode
        self.conversationIDs = conversationIDs
        self.phoneNumber = phoneNumber
        self.region = region
    }
    
    //==================================================//
    
    /* MARK: - Getter Functions */
    
    public func canStartConversation(with user: User,
                                     completion: @escaping(_ canStart: Bool,
                                                           _ exception: Exception?) -> Void) {
        guard user.identifier != identifier else {
            completion(false, Exception("Cannot start a conversation with yourself.",
                                        metadata: [#file, #function, #line]))
            return
        }
        
        deSerializeConversations(completion: { (returnedConversations,
                                                exception) in
            guard let conversations = returnedConversations else {
                completion(false, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            guard !conversations.contains(where: { $0.participants.contains(where: { $0.userID == user.identifier }) }) else {
                completion(false, Exception("Conversation with this user already exists.",
                                            extraParams: ["UserID": user.identifier!],
                                            metadata: [#file, #function, #line]))
                return
            }
            
            completion(true, nil)
        })
    }
    
    public func deSerializeConversations(completion: @escaping (_ conversations: [Conversation]?,
                                                                _ exception: Exception?) -> Void) {
        GeneralSerializer.getValues(atPath: "/allUsers/\(identifier!)/openConversations") { returnedIdentifiers, exception in
            guard let updatedIdentifiers = returnedIdentifiers as? [String] else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            guard updatedIdentifiers != ["!"] else {
                completion([], nil/*"No conversations to deserialize."*/)
                return
            }
            
            print("Conversations: \(updatedIdentifiers.count)")
            
            guard let asConversationIDs = updatedIdentifiers.asConversationIDs else {
                completion(nil, Exception("Unable to deserialize «openConversations».",
                                          metadata: [#file, #function, #line]))
                return
            }
            
            if asConversationIDs == self.conversationIDs,
               let openConversations = self.openConversations
            {
                completion(openConversations, nil)
            } else {
                let sorted = self.sortConversations(asConversationIDs)
                guard var conversationsToReturn = sorted[0] as? [Conversation],
                      let conversationsToUpdate = sorted[1] as? [Conversation],
                      let conversationsToFetch = sorted[2] as? [ConversationID] else {
                    completion(nil, Exception("Unable to sort conversations.",
                                              metadata: [#file, #function, #line]))
                    return
                }
                
                print("Conversations needing update: \(conversationsToUpdate.count)")
                print("Conversations needing fetch: \(conversationsToFetch.count)\(conversationsToFetch.count > 0 ? "\n" : "")")
                
                self.updateConversations(conversationsToUpdate) { (returnedConversations,
                                                                   exception) in
                    guard let updatedConversations = returnedConversations else {
                        completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                        return
                    }
                    
                    conversationsToReturn.append(contentsOf: updatedConversations)
                    
                    self.fetchConversations(conversationsToFetch) { (returnedConversations,
                                                                     exception) in
                        guard let fetchedConversations = returnedConversations else {
                            completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                            return
                        }
                        
                        conversationsToReturn.append(contentsOf: fetchedConversations)
                        
                        guard !conversationsToReturn.isEmpty else {
                            completion(nil, Exception("Conversations to return is still empty!",
                                                      metadata: [#file, #function, #line]))
                            return
                        }
                        
                        self.openConversations = conversationsToReturn
                        ConversationArchiver.addToArchive(conversationsToReturn)
                        completion(conversationsToReturn, nil)
                    }
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Setter Functions */
    
    public func update(isTyping: Bool,
                       inConversationWithID: String,
                       completion: @escaping (_ exception: Exception?) -> Void = { _ in }) {
        GeneralSerializer.getValues(atPath: "/allConversations/\(inConversationWithID)") { returnedValues, exception in
            guard let values = returnedValues as? [String: Any] else {
                let error = exception ?? Exception(metadata: [#file, #function, #line])
                
                Logger.log(error)
                completion(error)
                return
            }
            
            guard let participants = values["participants"] as? [String] else {
                completion(Exception("Couldn't deserialize participants.",
                                     metadata: [#file, #function, #line]))
                return
            }
            
            let otherUserID = participants.filter { $0.components(separatedBy: " | ")[0] != self.identifier! }.first!
            let updatedParticipants = ["\(self.identifier!) | \(isTyping)", otherUserID]
            
            GeneralSerializer.setValue(onKey: "/allConversations/\(inConversationWithID)/participants",
                                       withData: updatedParticipants) { returnedError in
                guard let error = returnedError else {
                    completion(nil)
                    return
                }
                
                completion(Exception(error, metadata: [#file, #function, #line]))
            }
        }
    }
    
    public func updateLastActiveDate() {
        GeneralSerializer.setValue(onKey: "/allUsers/\(identifier!)/lastActive",
                                   withData: Core.secondaryDateFormatter!.string(from: Date())) { returnedError in
            if let error = returnedError {
                Logger.log(Exception(error,
                                     extraParams: ["UserFacingDescriptor": "Update last active date failed!"],
                                     metadata: [#file, #function, #line]))
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func fetchConversations(_ identifiers: [ConversationID],
                                    completion: @escaping (_ returnedConversations: [Conversation]?,
                                                           _ exception: Exception?) -> Void) {
        
        guard identifiers.count > 0 else {
            completion([], nil)
            return
        }
        
        ConversationSerializer.shared.getConversations(withIdentifiers: identifiers.keys) { (returnedConversations,
                                                                                             exception) in
            guard let fetchedConversations = returnedConversations else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            let dispatchGroup = DispatchGroup()
            var exceptions = [Exception]()
            
            for conversation in fetchedConversations {
                dispatchGroup.enter()
                
                conversation.setOtherUser { (exception) in
                    if let error = exception {
                        exceptions.append(error)
                    }
                    
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                if fetchedConversations.count + exceptions.count == identifiers.count {
                    completion(fetchedConversations.isEmpty ? nil : fetchedConversations,
                               exceptions.compiledException)
                } else {
                    let failedToGet = identifiers.keys.filter({ !fetchedConversations.identifierKeys().contains($0) })
                    let mismatchedException = Exception("Mismatched conversation input/output.",
                                                        extraParams: ["FailedToGet": failedToGet],
                                                        metadata: [#file, #function, #line])
                    
                    let finalException = exception == nil ? mismatchedException : exception!.appending(underlyingException: mismatchedException)
                    
                    completion(nil, finalException)
                }
            }
        }
    }
    
    private func sortConversations(_ identifiers: [ConversationID]) -> [[Any]] {
        var conversationsToReturn = [Conversation]()
        var conversationsToUpdate = [Conversation]()
        var conversationsToFetch = [ConversationID]()
        
        for identifier in identifiers {
            let keyPrefix = identifier.key!.characterArray[0...4].joined()
            let hashPrefix = identifier.hash!.characterArray[0...3].joined()
            
            print("\nSearching archive for \(keyPrefix) | \(hashPrefix)")
            
            if let conversation = ConversationArchiver.getFromArchive(identifier) {
                print("Found \(keyPrefix) | \(hashPrefix) already in archive! – Up to date.\n")
                conversationsToReturn.append(conversation)
            } else {
                if let archivedConversation = ConversationArchiver.getFromArchive(withKey: identifier.key) {
                    print("Found \(keyPrefix) in archive, but needs update.\n")
                    conversationsToUpdate.append(archivedConversation)
                } else {
                    print("Didn't find \(keyPrefix) | \(hashPrefix) in archive.\n")
                    conversationsToFetch.append(identifier)
                }
            }
        }
        
        return [conversationsToReturn, conversationsToUpdate, conversationsToFetch]
    }
    
    //NOT MUTUALLY EXCLUSIVE RETURN.
    private func updateConversations(_ conversations: [Conversation],
                                     completion: @escaping (_ returnedConversations: [Conversation]?,
                                                            _ exception: Exception?) -> Void) {
        guard conversations.count > 0 else {
            completion([], nil)
            return
        }
        
        ConversationSerializer.shared.updateConversations(conversations) { (returnedConversations,
                                                                            exception) in
            guard let updatedConversations = returnedConversations else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            let dispatchGroup = DispatchGroup()
            var exceptions = [Exception]()
            
            for conversation in updatedConversations {
                dispatchGroup.enter()
                
                if conversation.otherUser != nil {
                    dispatchGroup.leave()
                } else {
                    conversation.setOtherUser { (exception) in
                        if let error = exception {
                            exceptions.append(error)
                        }
                        
                        dispatchGroup.leave()
                    }
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                if updatedConversations.count + exceptions.count == conversations.count {
                    completion(updatedConversations.isEmpty ? nil : updatedConversations,
                               exceptions.compiledException)
                } else {
                    let failedToGet = conversations.identifierKeys().filter({ !updatedConversations.identifierKeys().contains($0) })
                    completion(nil, Exception("Mismatched conversation input/output.",
                                              extraParams: ["FailedToGet": failedToGet],
                                              metadata: [#file, #function, #line]))
                }
            }
        }
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: Array */
public extension Array where Element == User {
    func callingCodes() -> [String] {
        var callingCodes = [String]()
        
        for user in self {
            callingCodes.append(user.callingCode)
        }
        
        return callingCodes
    }
    
    func identifiers() -> [String] {
        var identifiers = [String]()
        
        for user in self {
            identifiers.append(user.identifier)
        }
        
        return identifiers
    }
    
    func rawPhoneNumbers() -> [String] {
        var phoneNumbers = [String]()
        
        for user in self {
            phoneNumbers.append(user.phoneNumber)
        }
        
        return phoneNumbers
    }
    
    func uniquedByIdentifiers() -> [User] {
        var unique = [User]()
        
        for user in self {
            if !unique.contains(where: { $0.identifier == user.identifier }) {
                unique.append(user)
            }
        }
        
        return unique
    }
}

/* MARK: PhoneNumberFormat */
public extension PhoneNumberFormat {
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

/* MARK: Sequence */
public extension Sequence where Iterator.Element == String {
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

/* MARK: String */
public extension String {
    func callingCodeFormatted(region: String) -> String {
        let phoneNumberKit = PhoneNumberKit()
        let callingCode = RuntimeStorage.callingCodeDictionary?[region] ?? ""
        
        let mutableSelf = self
        let digits = mutableSelf.digits
        let nationalNumber = digits.dropPrefix(callingCode.count)
        
        var formattedNumber = "\(nationalNumber)"
        
        do {
            let parsed = try phoneNumberKit.parse("\(nationalNumber)", withRegion: region)
            
            formattedNumber = phoneNumberKit.format(parsed, toType: .international)
            formattedNumber = formattedNumber.removingOccurrences(of: ["+"])
        } catch { }
        
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
        guard let callingCode = RuntimeStorage.callingCodeDictionary![region] else { return self }
        
        let phoneNumberKit = PhoneNumberKit()
        
        let mutableSelf = self
        let digits = mutableSelf.digits
        
        guard digits.count != 10 && callingCode != "1" else {
            let formatted = PartialFormatter(phoneNumberKit: PhoneNumberKit(),
                                             defaultRegion: "US",
                                             withPrefix: true,
                                             maxDigits: nil).formatPartial(digits)
            return formatted.replacingOccurrences(of: "1(", with: "(")
        }
        
        var formattedNumber = "\(callingCode)\(digits)"
        
        do {
            let parsed = try phoneNumberKit.parse("\(digits)", withRegion: region)
            
            formattedNumber = phoneNumberKit.format(parsed, toType: .international)
            formattedNumber = formattedNumber.removingOccurrences(of: ["+"])
        } catch { }
        
        if !formattedNumber.contains(" ") {
            formattedNumber = PartialFormatter(phoneNumberKit: PhoneNumberKit(),
                                               defaultRegion: region,
                                               withPrefix: true,
                                               maxDigits: nil).formatPartial(digits)
        }
        
        if formattedNumber.characterArray.count(of: "-") == 2,
           formattedNumber.digits.count == 11 {
            formattedNumber = "\(PartialFormatter().formatPartial(self))"
        }
        
        return (formattedNumber.hasPrefix("\(callingCode) ") ? formattedNumber.dropPrefix(callingCode.count + 1) : formattedNumber).replacingOccurrences(of: "1(", with: "(")
    }
}

/* MARK: User */
public extension User {
    var cellTitle: String {
        var regionCode = RegionDetailServer.getRegionCode(forCallingCode: callingCode)
        regionCode = (regionCode == "multiple" && callingCode == "1") ? "US" : regionCode
        
        let formattedNumber = phoneNumber.formattedPhoneNumber(region: regionCode)
        var contactName = "+\(callingCode!) \(formattedNumber)"
        
        if let name = ContactService.fetchContactName(forNumber: phoneNumber),
           !(name.givenName.lowercasedTrimmingWhitespace == "" && name.familyName.lowercasedTrimmingWhitespace == "") {
            contactName = "\(name.givenName) \(name.familyName)"
        } else if let name = ContactService.fetchContactName(forNumber: "\(callingCode!)\(phoneNumber!)".digits),
                  !(name.givenName.lowercasedTrimmingWhitespace == "" && name.familyName.lowercasedTrimmingWhitespace == "") {
            contactName = "\(name.givenName) \(name.familyName)"
        }
        
        return contactName
    }
}
