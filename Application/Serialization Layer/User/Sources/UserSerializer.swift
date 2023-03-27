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
    
    /* MARK: - Creation Methods */
    
    public func createUser(_ identifier: String,
                           callingCode: String,
                           languageCode: String,
                           phoneNumber: String,
                           pushTokens: [String]?,
                           region: String,
                           completion: @escaping(_ exception: Exception?) -> Void) {
        let data = ["languageCode": languageCode,
                    "callingCode": callingCode.digits,
                    "phoneNumber": phoneNumber.digits,
                    "pushTokens": pushTokens ?? ["!"],
                    "region": region,
                    "openConversations": ["!"]] as [String: Any]
        
        let pathPrefix = "/\(GeneralSerializer.environment.shortString)/users/"
        GeneralSerializer.updateChildValues(forKey: "\(pathPrefix)\(identifier)",
                                            with: data) { exception in
            guard exception == nil else {
                completion(exception)
                return
            }
            
            GeneralSerializer.getValues(atPath: "/\(GeneralSerializer.environment.shortString)/userHashes/\(phoneNumber.digits.compressedHash)") { values, exception in
                var newValues = [identifier]
                
                if let values = values as? [String] {
                    newValues.append(contentsOf: values)
                }
                
                GeneralSerializer.setValue(newValues.unique(),
                                           forKey: "/\(GeneralSerializer.environment.shortString)/userHashes/\(phoneNumber.digits.compressedHash)") { exception in
                    guard let exception else {
                        completion(nil)
                        return
                    }
                    
                    completion(exception)
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Retrieval by Contact */
    
    public func findUsers(for contact: Contact,
                          completion: @escaping(_ numberPairs: [NumberPair]?,
                                                _ exception: Exception?) -> Void) {
        UserSerializer.shared.findUsers(for: contact.phoneNumbers.digits) { pairs, exception in
            guard let pairs else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(pairs, nil)
        }
    }
    
    public func findUsers(for contacts: [Contact],
                          completion: @escaping(_ pairs: [ContactPair]?,
                                                _ exception: Exception?) -> Void) {
        var pairs = [ContactPair]()
        var exceptions = [Exception]()
        
        let dispatchGroup = DispatchGroup()
        for contact in contacts {
            dispatchGroup.enter()
            findUsers(for: contact) { numberPairs, exception in
                guard let numberPairs else {
                    let error = exception ?? Exception(metadata: [#file, #function, #line])
                    
                    if !error.isEqual(toAny: [.mismatchedHashAndCallingCode,
                                              .noCallingCodesForNumber,
                                              .noHashesForNumber,
                                              .noUserWithHashes,
                                              .noUserWithCallingCode,
                                              .noUserWithPhoneNumber]) {
                        exceptions.append(error)
                    }
                    
                    dispatchGroup.leave()
                    return
                }
                
                pairs.append(ContactPair(contact: contact, numberPairs: numberPairs))
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(pairs.isEmpty ? nil : pairs,
                       exceptions.compiledException)
        }
    }
    
    //==================================================//
    
    /* MARK: - Retrieval by Hash */
    
    private func getUserHashes(completion: @escaping(_ hashes: [String: [String]]?,
                                                     _ exception: Exception?) -> Void) {
        GeneralSerializer.getValues(atPath: "/\(GeneralSerializer.environment.shortString)/userHashes") { returnedValues, exception in
            
            guard let values = returnedValues as? [String: [String]] else {
                completion(nil, Exception("Couldn't get user hashes.", metadata: [#file, #function, #line]))
                return
            }
            
            completion(values, nil)
        }
    }
    
    private func getUserIDs(fromHashes: [String],
                            completion: @escaping(_ userIDs: [String: [String]]?,
                                                  _ exception: Exception?) -> Void) {
        getUserHashes { hashes, exception in
            guard let hashes else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            var matches = [String: [String]]()
            for hash in fromHashes {
                guard let userIDs = hashes[hash] else { continue }
                matches[hash] = userIDs
            }
            
            completion(matches.isEmpty ? nil : matches,
                       matches.isEmpty ? Exception("No user exists with the possible hashes.",
                                                   extraParams: ["PossibleHashes": fromHashes],
                                                   metadata: [#file, #function, #line]) : nil)
        }
    }
    
    //==================================================//
    
    /* MARK: - Retrieval by Identifier */
    
    public func getUser(withIdentifier: String,
                        completion: @escaping(_ user: User?,
                                              _ exception: Exception?) -> Void) {
        Database.database().reference().child(GeneralSerializer.environment.shortString).child("users").child(withIdentifier).observeSingleEvent(of: .value, with: { snapshot in
            guard let snapshot = snapshot.value as? NSDictionary,
                  var data = snapshot as? [String: Any] else {
                completion(nil, Exception("No user exists with the provided identifier.",
                                          extraParams: ["UserID": withIdentifier],
                                          metadata: [#file, #function, #line]))
                return
            }
            
            data["identifier"] = withIdentifier
            
            self.deSerializeUser(fromData: data) { (user,
                                                    exception) in
                guard let user else {
                    completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                completion(user, nil)
            }
        }) { (error) in
            completion(nil, Exception(error, metadata: [#file, #function, #line]))
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
    
    /* MARK: - Retrieval by Phone Number */
    
    public func findUsers(for phoneNumbers: [String],
                          completion: @escaping(_ numberPairs: [NumberPair]?,
                                                _ exception: Exception?) -> Void) {
        var matches = [NumberPair]()
        var exceptions = [Exception]()
        
        let dispatchGroup = DispatchGroup()
        for number in phoneNumbers {
            dispatchGroup.enter()
            findUsers(for: number) { users, exception in
                guard let users else {
                    exceptions.append(exception ?? Exception(metadata: [#file, #function, #line]))
                    dispatchGroup.leave()
                    return
                }
                
                matches.append(NumberPair(number: number, users: users))
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(matches.isEmpty ? nil : matches,
                       exceptions.compiledException)
        }
    }
    
    public func findUsers(for phoneNumber: String,
                          completion: @escaping(_ users: [User]?,
                                                _ exception: Exception?) -> Void) {
        var users = [User]()
        
        guard let possibleHashes = PhoneNumberService.possibleHashes(for: phoneNumber) else {
            completion(nil, Exception("No possible hashes for this number.",
                                      extraParams: ["PhoneNumber": phoneNumber],
                                      metadata: [#file, #function, #line]))
            return
        }
        
        guard let possibleCallingCodes = PhoneNumberService.possibleCallingCodes(for: phoneNumber) else {
            completion(nil, Exception("No possible calling codes for this number.",
                                      extraParams: ["PhoneNumber": phoneNumber],
                                      metadata: [#file, #function, #line]))
            return
        }
        
        getUserIDs(fromHashes: possibleHashes) { userIDs, exception in
            guard let userIDs else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            let values = userIDs.values.reduce([], +)
            getUsers(withIdentifiers: values) { returnedUsers, exception in
                guard let returnedUsers else {
                    completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                for user in returnedUsers {
                    if possibleCallingCodes.contains(user.callingCode) {
                        users.append(user)
                    }
                }
                
                guard !users.isEmpty else {
                    var mismatches = RuntimeStorage.mismatchedHashes!
                    mismatches.append(contentsOf: possibleHashes)
                    mismatches = mismatches.unique()
                    
                    RuntimeStorage.store(mismatches, as: .mismatchedHashes)
                    UserDefaults.standard.set(mismatches, forKey: "mismatchedHashes")
                    
                    completion(nil, Exception("There are matching hashes for this number, but no users have any of the possible calling codes.",
                                              extraParams: ["PhoneNumber": phoneNumber],
                                              metadata: [#file, #function, #line]))
                    return
                }
                
                completion(users, nil)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func deSerializeUser(fromData: [String: Any],
                                 completion: @escaping(_ deSerializedUser: User?,
                                                       _ exception: Exception?) -> Void) {
        guard let identifier = fromData["identifier"] as? String else {
            completion(nil, Exception("Unable to deserialize «identifier».", metadata: [#file, #function, #line]))
            return
        }
        
        guard let callingCode = fromData["callingCode"] as? String else {
            completion(nil, Exception("Unable to deserialize «callingCode».", metadata: [#file, #function, #line]))
            return
        }
        
        guard let languageCode = fromData["languageCode"] as? String else {
            completion(nil, Exception("Unable to deserialize «languageCode».", metadata: [#file, #function, #line]))
            return
        }
        
        guard let conversationIdentifiers = fromData["openConversations"] as? [String] else {
            completion(nil, Exception("Unable to deserialize «openConversations».", metadata: [#file, #function, #line]))
            return
        }
        
        guard let phoneNumber = fromData["phoneNumber"] as? String else {
            completion(nil, Exception("Unable to deserialize «phoneNumber».", metadata: [#file, #function, #line]))
            return
        }
        
        guard let pushTokens = fromData["pushTokens"] as? [String] else {
            completion(nil, Exception("Unable to deserialize «pushTokens».", metadata: [#file, #function, #line]))
            return
        }
        
        guard let region = fromData["region"] as? String else {
            completion(nil, Exception("Unable to deserialize «region».", metadata: [#file, #function, #line]))
            return
        }
        
        let deSerializedUser = User(identifier: identifier,
                                    callingCode: callingCode,
                                    languageCode: languageCode,
                                    conversationIDs: conversationIdentifiers.asConversationIDs,
                                    phoneNumber: phoneNumber,
                                    pushTokens: pushTokens == ["!"] ? nil : pushTokens,
                                    region: region)
        
        completion(deSerializedUser, nil)
    }
}
