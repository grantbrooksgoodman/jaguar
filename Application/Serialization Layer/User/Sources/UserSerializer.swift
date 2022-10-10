//
//  UserSerializer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 01/05/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import Firebase
import FirebaseDatabase

public struct UserSerializer {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public static let shared = UserSerializer()
    
    //==================================================//
    
    /* MARK: - Creation Functions */
    
    public func createUser(_ identifier: String,
                           callingCode: String,
                           languageCode: String,
                           phoneNumber: String,
                           region: String,
                           completion: @escaping(_ errorDescriptor: String?) -> Void) {
        let data = ["languageCode": languageCode,
                    "callingCode": callingCode.digits,
                    "phoneNumber": phoneNumber.digits,
                    "region": region,
                    "openConversations": ["!"]] as [String: Any]
        
        GeneralSerializer.updateValue(onKey: "/allUsers/\(identifier)",
                                      withData: data) { (returnedError) in
            guard returnedError == nil else {
                completion(Logger.errorInfo(returnedError!))
                return
            }
            
            GeneralSerializer.getValues(atPath: "/userHashes/\(phoneNumber.digits.compressedHash)") { returnedValues, errorDescriptor in
                var newValues = [identifier]
                
                if let values = returnedValues as? [String] {
                    newValues.append(contentsOf: values)
                }
                
                GeneralSerializer.setValue(onKey: "/userHashes/\(phoneNumber.digits.compressedHash)",
                                           withData: newValues.unique()) { returnedError in
                    guard let error = returnedError else {
                        completion(nil)
                        return
                    }
                    
                    completion(Logger.errorInfo(error))
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Query Functions */
    
    public func getUsers(possibleHashes: [String],
                         possibleCallingCodes: [String],
                         completion: @escaping(_ returnedUsers: [User]?,
                                               _ errorDescriptor: String?) -> Void) {
        getUserIDs(fromHashes: possibleHashes) { returnedUserIDs, errorDescriptor in
            guard let userIDs = returnedUserIDs else {
                completion(nil, "No user exists with the possible hashes.")
                return
            }
            
            getUsers(withIdentifiers: userIDs) { returnedUsers, errorDescriptor in
                guard let users = returnedUsers else {
                    completion(nil, errorDescriptor ?? "An unknown error occurred.")
                    return
                }
                
                var possibleUsers = [User]()
                for user in users {
                    if possibleCallingCodes.contains(user.callingCode) {
                        possibleUsers.append(user)
                    }
                }
                
                guard !possibleUsers.isEmpty else {
                    completion(nil, "Found users, but none with this calling code.")
                    return
                }
                
                completion(possibleUsers, nil)
            }
        }
    }
    
    public func getUsers(withIdentifiers: [String],
                         completion: @escaping(_ returnedUsers: [User]?,
                                               _ errorDescriptor: String?) -> Void) {
        var users = [User]()
        var errors = [String]()
        
        for (index, identifier) in withIdentifiers.enumerated() {
            getUser(withIdentifier: identifier) { returnedUser, errorDescriptor in
                if let user = returnedUser {
                    users.append(user)
                } else {
                    errors.append(errorDescriptor ?? "An unknown error occurred.")
                }
                
                if index == withIdentifiers.count - 1 {
                    completion(users.isEmpty ? nil : users,
                               errors.isEmpty ? nil : errors.joined(separator: "\n"))
                }
            }
        }
    }
    
    public func getUserIDs(fromHashes: [String],
                           completion: @escaping (_ returnedUserIDs: [String]?,
                                                  _ errorDescriptor: String?) -> Void) {
        var userIDs = [String]()
        var errors = [String]()
        
        for (index, hash) in fromHashes.enumerated() {
            getUserIDs(fromHash: hash) { returnedUserIDs, errorDescriptor in
                if let identifiers = returnedUserIDs {
                    userIDs.append(contentsOf: identifiers)
                } else {
                    errors.append(errorDescriptor ?? "An unknown error occurred.")
                }
                
                if index == fromHashes.count - 1 {
                    completion(userIDs.isEmpty ? nil : userIDs,
                               errors.isEmpty ? nil : errors.joined(separator: "\n"))
                }
            }
        }
    }
    
    public func getUserIDs(fromHash: String,
                           completion: @escaping (_ returnedUserIDs: [String]?,
                                                  _ errorDescriptor: String?) -> Void) {
        GeneralSerializer.getValues(atPath: "/userHashes/\(fromHash)") { returnedValues, errorDescriptor in
            
            guard let values = returnedValues as? [String] else {
                completion(nil, "No user IDs for this hash.")
                return
            }
            
            completion(values, nil)
        }
    }
    
    public func findUser(phoneNumber: String,
                         possibleCallingCodes: [String],
                         completion: @escaping(_ returnedUser: User?,
                                               _ errorDescriptor: String?) -> Void) {
        let userIdentifier = phoneNumber.digits.compressedHash
        
        getUser(withIdentifier: userIdentifier) { returnedUser, errorDescriptor in
            guard let user = returnedUser else {
                completion(nil, errorDescriptor ?? "No user exists with this identifier.")
                return
            }
            
            if possibleCallingCodes.contains(user.callingCode) {
                completion(user, nil)
            } else {
                completion(nil, "User exists with this number, but not any of the possible calling codes.")
            }
        }
    }
    
    public func sortContacts(_ contacts: [Contact]) -> [[Any]] {
        var contactsToReturn = [ContactPair]()
        var contactsToFetch = [Contact]()
        
        //        if contactArchive.hashes().containsAll(in: contacts.hashes()) {
        //            print("Contact archive is up to date with device!")
        //            return [contacts, [], []]
        //        }
        
        for contact in contacts {
            guard let retrievedContact = ContactArchiver.getFromArchive(contact.hash) else {
                contactsToFetch.append(contact)
                continue
            }
            
            contactsToReturn.append(retrievedContact)
        }
        
        return [contactsToReturn, contactsToFetch]
    }
    
    public func validUsers(fromContacts: [Contact],
                           completion: @escaping (_ returnedContactPairs: [ContactPair]?,
                                                  _ errorDescriptor: String?) -> Void) {
        guard !fromContacts.isEmpty else {
            completion(nil, "No contacts passed!")
            return
        }
        
        var validContacts = [ContactPair]()
        var errors = [String]()
        
        for (index, contact) in fromContacts.enumerated() {
            if contact.phoneNumbers.count > 0 {
                self.validUsers(forPhoneNumbers: contact.phoneNumbers.digits) { returnedUsers, errorDescriptor in
                    if let users = returnedUsers {
                        //#warning("FIX THIS")
                        validContacts.append(ContactPair(contact: contact,
                                                         users: users))
                        completion(validContacts.isEmpty ? nil : validContacts,
                                   errors.isEmpty ? nil : errors.joined(separator: "\n"))
                    } else {
                        errors.append(errorDescriptor ?? "An unknown error occurred.")
                    }
                    
                    if index == fromContacts.count - 1 {
                        completion(validContacts.isEmpty ? nil : validContacts,
                                   errors.isEmpty ? nil : errors.joined(separator: "\n"))
                    }
                }
            } else {
                if index == fromContacts.count - 1 {
                    completion(validContacts.isEmpty ? nil : validContacts,
                               errors.isEmpty ? nil : errors.joined(separator: "\n"))
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Retrieval Functions */
    
    public func allUsersSnapshotData(completion: @escaping(_ returnedData: [String: Any]?,
                                                           _ errorDescriptor: String?) -> Void) {
        Database.database().reference().child("allUsers").observeSingleEvent(of: .value) { returnedSnapshot in
            guard let snapshot = returnedSnapshot.value as? NSDictionary,
                  let data = snapshot as? [String: Any] else {
                completion(nil, "Unable to retrieve the specified data.")
                return
            }
            
            completion(data, nil)
        } withCancel: { error in
            completion(nil, "Unable to retrieve the specified data. (\(Logger.errorInfo(error)))")
        }
    }
    
    public func getUser(withIdentifier: String,
                        completion: @escaping(_ returnedUser: User?,
                                              _ errorDescriptor: String?) -> Void) {
        Database.database().reference().child("allUsers").child(withIdentifier).observeSingleEvent(of: .value, with: { (returnedSnapshot) in
            guard let snapshot = returnedSnapshot.value as? NSDictionary,
                  var data = snapshot as? [String: Any] else {
                completion(nil, "No user exists with the identifier \"\(withIdentifier)\".")
                return
            }
            
            data["identifier"] = withIdentifier
            
            self.deSerializeUser(fromData: data) { (returnedUser,
                                                    errorDescriptor) in
                guard let user = returnedUser else {
                    completion(nil, errorDescriptor ?? "An unknown error occurred.")
                    return
                }
                
                completion(user, nil)
            }
        }) { (error) in
            completion(nil, "Unable to retrieve the specified data. (\(Logger.errorInfo(error)))")
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func deSerializeUser(fromData: [String: Any],
                                 completion: @escaping(_ deSerializedUser: User?,
                                                       _ errorDescriptor: String?) -> Void) {
        guard let identifier = fromData["identifier"] as? String else {
            completion(nil, "Unable to deserialize «identifier».")
            return
        }
        
        guard let callingCode = fromData["callingCode"] as? String else {
            completion(nil, "Unable to deserialize «callingCode».")
            return
        }
        
        guard let languageCode = fromData["languageCode"] as? String else {
            completion(nil, "Unable to deserialize «languageCode».")
            return
        }
        
        guard let conversationIdentifiers = fromData["openConversations"] as? [String] else {
            completion(nil, "Unable to deserialize «openConversations».")
            return
        }
        
        guard let phoneNumber = fromData["phoneNumber"] as? String else {
            completion(nil, "Unable to deserialize «phoneNumber».")
            return
        }
        
        guard let region = fromData["region"] as? String else {
            completion(nil, "Unable to deserialize «region».")
            return
        }
        
        let deSerializedUser = User(identifier: identifier,
                                    callingCode: callingCode,
                                    languageCode: languageCode,
                                    conversationIDs: conversationIdentifiers.asConversationIDs,
                                    phoneNumber: phoneNumber,
                                    region: region)
        
        completion(deSerializedUser, nil)
    }
    
    public func validUsers(forPhoneNumbers: [String],
                           completion: @escaping(_ returnedUsers: [User]?,
                                                 _ errorDescriptor: String?) -> Void) {
        var users = [User]()
        var errors = [String]()
        
        for (index, phoneNumber) in forPhoneNumbers.enumerated() {
            let possibleHashes = PhoneNumberService.possibleHashes(forNumber: phoneNumber.digits)
            let possibleCallingCodes = PhoneNumberService.possibleCallingCodes(forNumber: phoneNumber)
            
            getUsers(possibleHashes: possibleHashes,
                     possibleCallingCodes: possibleCallingCodes) { returnedUsers, errorDescriptor in
                if let unwrappedUsers = returnedUsers {
                    users.append(contentsOf: unwrappedUsers)
                } else {
                    errors.append(errorDescriptor ?? "An unknown error occurred.")
                }
                
                if index == forPhoneNumbers.count - 1 {
                    completion(users.isEmpty ? nil : users,
                               errors.isEmpty ? nil : errors.joined(separator: "\n"))
                }
            }
        }
    }
}
