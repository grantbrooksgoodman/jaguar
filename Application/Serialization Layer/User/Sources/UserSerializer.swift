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
                           completion: @escaping(_ exception: Exception?) -> Void) {
        let data = ["languageCode": languageCode,
                    "callingCode": callingCode.digits,
                    "phoneNumber": phoneNumber.digits,
                    "region": region,
                    "openConversations": ["!"]] as [String: Any]
        
        GeneralSerializer.updateValue(onKey: "/allUsers/\(identifier)",
                                      withData: data) { (returnedError) in
            guard returnedError == nil else {
                completion(Exception(returnedError!,
                                     metadata: [#file, #function, #line]))
                return
            }
            
            GeneralSerializer.getValues(atPath: "/userHashes/\(phoneNumber.digits.compressedHash)") { returnedValues, exception in
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
                    
                    completion(Exception(error, metadata: [#file, #function, #line]))
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Query Functions */
    
    public func findUsers(forContacts: [Contact],
                          completion: @escaping (_ returnedContactPairs: [ContactPair]?,
                                                 _ exception: Exception?) -> Void) {
        guard !forContacts.isEmpty else {
            completion(nil, Exception("No contacts passed!",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        var validContacts = [ContactPair]()
        var exceptions = [Exception]()
        
        let dispatchGroup = DispatchGroup()
        for contact in forContacts {
            dispatchGroup.enter()
            
            guard contact.phoneNumbers.count > 0 else { continue }
            
            self.findUsers(forPhoneNumbers: contact.phoneNumbers.digits) { returnedUsers, exception in
                if let users = returnedUsers {
                    validContacts.append(ContactPair(contact: contact,
                                                     users: users))
                } else {
                    exceptions.append(exception ?? Exception(metadata: [#file, #function, #line]))
                }
                
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(validContacts.isEmpty ? nil : validContacts,
                       exceptions.compiledException)
        }
    }
    
    public func findUsers(forPhoneNumbers: [String],
                          completion: @escaping(_ returnedUsers: [User]?,
                                                _ exception: Exception?) -> Void) {
        var users = [User]()
        var exceptions = [Exception]()
        
        let dispatchGroup = DispatchGroup()
        for phoneNumber in forPhoneNumbers {
            let possibleHashes = PhoneNumberService.possibleHashes(forNumber: phoneNumber.digits)
            let possibleCallingCodes = PhoneNumberService.possibleCallingCodes(forNumber: phoneNumber)
            
            dispatchGroup.enter()
            getUsers(possibleHashes: possibleHashes,
                     possibleCallingCodes: possibleCallingCodes) { returnedUsers, exception in
                if let unwrappedUsers = returnedUsers {
                    users.append(contentsOf: unwrappedUsers)
                } else {
                    exceptions.append(exception ?? Exception(metadata: [#file, #function, #line]))
                }
                
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(users.isEmpty ? nil : users,
                       exceptions.compiledException)
        }
    }
    
    //==================================================//
    
    /* MARK: - Retrieval by Hash */
    
    private func getUserIDs(fromHash: String,
                            completion: @escaping (_ returnedUserIDs: [String]?,
                                                   _ exception: Exception?) -> Void) {
        GeneralSerializer.getValues(atPath: "/userHashes/\(fromHash)") { returnedValues, exception in
            
            guard let values = returnedValues as? [String] else {
                completion(nil, Exception("No user IDs for this hash.",
                                          extraParams: ["Hash": fromHash],
                                          metadata: [#file, #function, #line]))
                return
            }
            
            completion(values, nil)
        }
    }
    
    private func getUserIDs(fromHashes: [String],
                            completion: @escaping (_ returnedUserIDs: [String]?,
                                                   _ exception: Exception?) -> Void) {
        var userIDs = [String]()
        var exceptions = [Exception]()
        
        for (index, hash) in fromHashes.enumerated() {
            getUserIDs(fromHash: hash) { returnedUserIDs, exception in
                if let identifiers = returnedUserIDs {
                    userIDs.append(contentsOf: identifiers)
                } else {
                    exceptions.append(exception?.appending(extraParams: ["hash": hash]) ?? Exception(extraParams: ["hash": hash],
                                                                                                     metadata: [#file, #function, #line]))
                }
                
                if index == fromHashes.count - 1 {
                    completion(userIDs.isEmpty ? nil : userIDs,
                               exceptions.compiledException)
                }
            }
        }
    }
    
    private func getUsers(possibleHashes: [String],
                          possibleCallingCodes: [String],
                          completion: @escaping(_ returnedUsers: [User]?,
                                                _ exception: Exception?) -> Void) {
        getUserIDs(fromHashes: possibleHashes) { returnedUserIDs, exception in
            guard let userIDs = returnedUserIDs else {
                completion(nil, Exception("No user exists with the possible hashes.",
                                          extraParams: ["PossibleHashes": possibleHashes],
                                          metadata: [#file, #function, #line]))
                return
            }
            
            getUsers(withIdentifiers: userIDs) { returnedUsers, exception in
                guard let users = returnedUsers else {
                    completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                var possibleUsers = [User]()
                for user in users {
                    if possibleCallingCodes.contains(user.callingCode) {
                        possibleUsers.append(user)
                    }
                }
                
                guard !possibleUsers.isEmpty else {
                    completion(nil, Exception("Found users, but none with this calling code.",
                                              extraParams: ["UserIDs": users.identifiers(),
                                                            "PossibleCallingCodes": possibleCallingCodes],
                                              metadata: [#file, #function, #line]))
                    return
                }
                
                completion(possibleUsers, nil)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Retrieval by Identifier */
    
    public func getUser(withIdentifier: String,
                        completion: @escaping(_ returnedUser: User?,
                                              _ exception: Exception?) -> Void) {
        Database.database().reference().child("allUsers").child(withIdentifier).observeSingleEvent(of: .value, with: { (returnedSnapshot) in
            guard let snapshot = returnedSnapshot.value as? NSDictionary,
                  var data = snapshot as? [String: Any] else {
                completion(nil, Exception("No user exists with the provided identifier.",
                                          extraParams: ["UserID": withIdentifier],
                                          metadata: [#file, #function, #line]))
                return
            }
            
            data["identifier"] = withIdentifier
            
            self.deSerializeUser(fromData: data) { (returnedUser,
                                                    exception) in
                guard let user = returnedUser else {
                    completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                completion(user, nil)
            }
        }) { (error) in
            completion(nil, Exception(error,
                                      metadata: [#file, #function, #line]))
        }
    }
    
    private func getUsers(withIdentifiers: [String],
                          completion: @escaping(_ returnedUsers: [User]?,
                                                _ exception: Exception?) -> Void) {
        var users = [User]()
        var exceptions = [Exception]()
        
        for (index, identifier) in withIdentifiers.enumerated() {
            getUser(withIdentifier: identifier) { returnedUser, exception in
                if let user = returnedUser {
                    users.append(user)
                } else {
                    exceptions.append(exception ?? Exception(metadata: [#file, #function, #line]))
                }
                
                if index == withIdentifiers.count - 1 {
                    completion(users.isEmpty ? nil : users,
                               exceptions.compiledException)
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func deSerializeUser(fromData: [String: Any],
                                 completion: @escaping(_ deSerializedUser: User?,
                                                       _ exception: Exception?) -> Void) {
        guard let identifier = fromData["identifier"] as? String else {
            completion(nil, Exception("Unable to deserialize «identifier».",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        guard let callingCode = fromData["callingCode"] as? String else {
            completion(nil, Exception("Unable to deserialize «callingCode».",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        guard let languageCode = fromData["languageCode"] as? String else {
            completion(nil, Exception("Unable to deserialize «languageCode».",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        guard let conversationIdentifiers = fromData["openConversations"] as? [String] else {
            completion(nil, Exception("Unable to deserialize «openConversations».",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        guard let phoneNumber = fromData["phoneNumber"] as? String else {
            completion(nil, Exception("Unable to deserialize «phoneNumber».",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        guard let region = fromData["region"] as? String else {
            completion(nil, Exception("Unable to deserialize «region».",
                                      metadata: [#file, #function, #line]))
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
}
