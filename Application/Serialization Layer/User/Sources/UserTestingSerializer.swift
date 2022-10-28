//
//  UserTestingSerializer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 27/08/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import Firebase
import FirebaseDatabase

import PhoneNumberKit

public struct UserTestingSerializer {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public static let shared = UserTestingSerializer()
    
    //==================================================//
    
    /* MARK: - Miscellaneous Functions */
    
    public func createRandomUser(region: String? = nil,
                                 completion: @escaping (_ returnedIdentifier: String?,
                                                        _ exception: Exception?) -> Void) {
        let randomRegionCode = region ?? RegionDetailServer.randomRegionCode()
        let phoneNumberKit = PhoneNumberKit()
        
        guard let regionMetadata = phoneNumberKit.metadata(for: randomRegionCode.uppercased()),
              let description = regionMetadata.mobile,
              let exampleNumber = description.exampleNumber else {
            completion(nil, Exception("Couldn't generate example number.",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        // TODO: Verfify user with same language code doesn't already exist
        
        guard let generatedKey = Database.database().reference().child("/allUsers/").childByAutoId().key else {
            completion(nil, Exception("Unable to generate key for new user.",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        UserSerializer.shared.createUser(generatedKey,
                                         callingCode: RuntimeStorage.callingCodeDictionary![randomRegionCode.uppercased()]!,
                                         languageCode: randomRegionCode.lowercased(),
                                         phoneNumber: exampleNumber.digits,
                                         region: randomRegionCode.uppercased()) { exception in
            guard exception == nil else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(generatedKey, nil)
        }
    }
    
    public func getRandomUserID(completion: @escaping (_ returnedIdentifier: String?,
                                                       _ exception: Exception?) -> Void) {
        Database.database().reference().child("/allUsers").observeSingleEvent(of: .value) { (returnedSnapshot) in
            guard let snapshot = returnedSnapshot.value as? NSDictionary,
                  let data = snapshot as? [String: Any] else {
                completion(nil, Exception("Couldn't get user list.",
                                          metadata: [#file, #function, #line]))
                return
            }
            
            completion(Array(data.keys).randomElement, nil)
        }
    }
    
    public func getRandomUserPair(completion: @escaping (_ returnedUsers: [User]?,
                                                         _ exception: Exception?) -> Void) {
        getAllUserIDs { returnedIdentifiers, exception in
            guard let identifiers = returnedIdentifiers else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            let randomUserIdPair = Array(identifiers.shuffledValue[0...1])
            let dispatchGroup = DispatchGroup()
            
            var users = [User]()
            for userId in randomUserIdPair {
                dispatchGroup.enter()
                UserSerializer.shared.getUser(withIdentifier: userId) { returnedUser, exception in
                    guard let user = returnedUser else {
                        completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                        dispatchGroup.leave()
                        return
                    }
                    
                    users.append(user)
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                if randomUserIdPair.count == users.count {
                    completion(users, nil)
                } else {
                    completion(nil, Exception("Mismatched identifier to user output.", metadata: [#file, #function, #line]))
                }
            }
        }
    }
    
    public func getAllUserIDs(completion: @escaping (_ returnedIdentifiers: [String]?,
                                                     _ exception: Exception?) -> Void) {
        Database.database().reference().child("/allUsers").observeSingleEvent(of: .value) { (returnedSnapshot) in
            guard let snapshot = returnedSnapshot.value as? NSDictionary,
                  let data = snapshot as? [String: Any] else {
                completion(nil, Exception("Couldn't get user list.",
                                          metadata: [#file, #function, #line]))
                return
            }
            
            completion(Array(data.keys), nil)
        }
    }
    
    public func signInNextUserInSequence(completion: @escaping (_ exception: Exception?) -> Void = { _ in }) {
        UserDefaults.standard.setValue(nil, forKey: "userList")
        UserDefaults.standard.setValue(0, forKey: "userListPosition")
        
        UserDefaults.standard.setValue(nil, forKey: "conversationArchive")
        UserDefaults.standard.setValue(nil, forKey: "conversationArchiveUserID")
        
        UserDefaults.standard.set(nil, forKey: "currentUserID")
        UserDefaults.standard.setValue(nil, forKey: "contactArchive")
        
        RuntimeStorage.remove(.currentUser)
        RuntimeStorage.remove(.currentUserID)
        
        if let userList = UserDefaults.standard.value(forKey: "userList") as? [String],
           let position = UserDefaults.standard.value(forKey: "userListPosition") as? Int {
            getSetUser(with: userList,
                       position: position) { exception in
                completion(exception)
            }
        } else {
            GeneralSerializer.getValues(atPath: "/allUsers") { returnedValues, returnedException in
                guard let values = returnedValues as? [String: Any] else {
                    completion(returnedException ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                UserDefaults.standard.setValue(Array(values.keys), forKey: "userList")
                UserDefaults.standard.setValue(0, forKey: "userListPosition")
                
                self.getSetUser(with: Array(values.keys),
                                position: 0) { exception in
                    completion(exception)
                }
            }
        }
    }
    
    public func signInUser(with phoneNumber: String,
                           completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        guard phoneNumber.digits.count > 0 else {
            completion(Exception("Invalid phone number",
                                 metadata: [#file, #function, #line]))
            return
        }
        
        UserSerializer.shared.findUsers(forPhoneNumbers: [phoneNumber.digits]) { returnedUsers, exception in
            guard let users = returnedUsers else {
                completion(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            guard users.count == 1 else {
                Logger.log("Multiple users for this phone number!",
                           metadata: [#file, #function, #line])
                return
            }
            
            RuntimeStorage.store(users[0].identifier!, as: .currentUserID)
            RuntimeStorage.store(users[0], as: .currentUser)
            
            completion(nil)
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func getSetUser(with list: [String],
                            position: Int,
                            completion: @escaping (_ exception: Exception?) -> Void = { _ in }) {
        var position = position
        
        guard position + 1 < list.count else {
            UserDefaults.standard.setValue(0, forKey: "userListPosition")
            UserSerializer.shared.getUser(withIdentifier: list[0]) { returnedUser, exception in
                guard let user = returnedUser else {
                    completion(exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                RuntimeStorage.store(user, as: .currentUser)
                RuntimeStorage.store(user.identifier!, as: .currentUserID)
                
                UserDefaults.standard.setValue(nil, forKey: "userList")
                completion(nil)
            }
            
            return
        }
        
        position += 1
        UserDefaults.standard.setValue(position, forKey: "userListPosition")
        let userToGet = list[position]
        
        UserSerializer.shared.getUser(withIdentifier: userToGet) { returnedUser, exception in
            guard let user = returnedUser else {
                completion(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            RuntimeStorage.store(user, as: .currentUser)
            RuntimeStorage.store(user.identifier!, as: .currentUserID)
            
            completion(nil)
        }
    }
}
