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
                                                        _ errorDescriptor: String?) -> Void) {
        let randomRegionCode = region ?? RegionDetailServer.randomRegionCode()
        let phoneNumberKit = PhoneNumberKit()
        
        guard let regionMetadata = phoneNumberKit.metadata(for: randomRegionCode.uppercased()),
              let description = regionMetadata.mobile,
              let exampleNumber = description.exampleNumber else {
            completion(nil, "Couldn't generate example number.")
            return
        }
        
        // TODO: Verfify user with same language code doesn't already exist
        
        guard let generatedKey = Database.database().reference().child("/allUsers/").childByAutoId().key else {
            completion(nil, "Unable to generate key for new user.")
            return
        }
        
        UserSerializer.shared.createUser(generatedKey,
                                         callingCode: RuntimeStorage.callingCodeDictionary![randomRegionCode.uppercased()]!,
                                         languageCode: randomRegionCode.lowercased(),
                                         phoneNumber: exampleNumber.digits,
                                         region: randomRegionCode.uppercased()) { errorDescriptor in
            guard errorDescriptor == nil else {
                completion(nil, errorDescriptor ?? "An unknown error occurred.")
                return
            }
            
            completion(generatedKey, nil)
        }
    }
    
    public func getRandomUserID(completion: @escaping (_ returnedIdentifier: String?,
                                                       _ errorDescriptor: String?) -> Void) {
        Database.database().reference().child("/allUsers").observeSingleEvent(of: .value) { (returnedSnapshot) in
            guard let snapshot = returnedSnapshot.value as? NSDictionary,
                  let data = snapshot as? [String: Any] else {
                completion(nil, "Couldn't get user list.")
                return
            }
            
            completion(Array(data.keys).randomElement, nil)
        }
    }
    
    public func signInNextUserInSequence(completion: @escaping (_ errorDescriptor: String?) -> Void = { _ in }) {
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
                       position: position) { errorDescriptor in
                completion(errorDescriptor)
            }
        } else {
            GeneralSerializer.getValues(atPath: "/allUsers") { returnedValues, errorDescriptor in
                guard let values = returnedValues as? [String: Any] else {
                    completion(errorDescriptor ?? "An unknown error occurred.")
                    return
                }
                
                UserDefaults.standard.setValue(Array(values.keys), forKey: "userList")
                UserDefaults.standard.setValue(0, forKey: "userListPosition")
                
                self.getSetUser(with: Array(values.keys),
                                position: 0) { errorDescriptor in
                    completion(errorDescriptor)
                }
            }
        }
    }
    
    public func signInUser(with phoneNumber: String,
                           completion: @escaping(_ errorDescriptor: String?) -> Void = { _ in }) {
        guard phoneNumber.digits.count > 0 else {
            completion("Invalid phone number")
            return
        }
        
        UserSerializer.shared.validUsers(forPhoneNumbers: [phoneNumber.digits]) { returnedUsers, errorDescriptor in
            guard let users = returnedUsers else {
                completion(errorDescriptor ?? "An unknown error occurred.")
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
                            completion: @escaping (_ errorDescriptor: String?) -> Void = { _ in }) {
        var position = position
        
        guard position + 1 < list.count else {
            UserDefaults.standard.setValue(0, forKey: "userListPosition")
            UserSerializer.shared.getUser(withIdentifier: list[0]) { returnedUser, errorDescriptor in
                guard let user = returnedUser else {
                    completion(errorDescriptor ?? "An unknown error occurred.")
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
        
        UserSerializer.shared.getUser(withIdentifier: userToGet) { returnedUser, errorDescriptor in
            guard let user = returnedUser else {
                completion(errorDescriptor ?? "An unknown error occurred.")
                return
            }
            
            RuntimeStorage.store(user, as: .currentUser)
            RuntimeStorage.store(user.identifier!, as: .currentUserID)
            
            completion(nil)
        }
    }
}
