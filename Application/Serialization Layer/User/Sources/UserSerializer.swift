//
//  UserSerializer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 01/05/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

/* Third-party Frameworks */
import Firebase

public struct UserSerializer {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    public static let shared = UserSerializer()
    
    //==================================================//
    
    /* MARK: - Creation Functions */
    
    public func createUser(_ identifier: String,
                           languageCode: String,
                           phoneNumber: String,
                           region: String,
                           completion: @escaping(_ errorDescriptor: String?) -> Void) {
        let dataBundle = ["languageCode": languageCode,
                          "phoneNumber": phoneNumber.digits,
                          "region": region,
                          "openConversations": ["!"]] as [String: Any]
        
        GeneralSerializer.updateValue(onKey: "/allUsers/\(identifier)",
                                      withData: dataBundle) { (returnedError) in
            if let error = returnedError {
                completion(Logger.errorInfo(error))
            } else {
                completion(nil)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Retrieval Functions */
    
    public func findUser(byPhoneNumber: String,
                         completion: @escaping(_ returnedUser: User?,
                                               _ errorDescriptor: String?) -> Void) {
        Database.database().reference().child("allUsers").observeSingleEvent(of: .value, with: { (returnedSnapshot) in
            if let returnedSnapshotAsDictionary = returnedSnapshot.value as? NSDictionary,
               let asData = returnedSnapshotAsDictionary as? [String: Any] {
                guard asData.count > 0 else {
                    completion(nil, "Couldn't get users.")
                    return
                }
                
                var found = false
                
                for user in asData {
                    if var userData = user.value as? [String: Any],
                       let phoneNumberString = userData["phoneNumber"] as? String,
                       phoneNumberString.digits == byPhoneNumber.digits {
                        userData["identifier"] = user.key
                        
                        found = true
                        UserSerializer.shared.deSerializeUser(fromData: userData) { (returnedUser,
                                                                                     errorDescriptor) in
                            if let error = errorDescriptor {
                                completion(nil, error)
                            } else if let foundUser = returnedUser {
                                completion(foundUser, nil)
                            }
                        }
                    }
                }
                
                if !found {
                    completion(nil, "No user exists with the provided phone number.")
                }
            } else {
                completion(nil, "No user exists with the provided phone number.")
            }
        }) { (error) in
            completion(nil, "Unable to retrieve the specified data. (\(Logger.errorInfo(error)))")
        }
    }
    
    public func getUser(withIdentifier: String,
                        completion: @escaping(_ returnedUser: User?,
                                              _ errorDescriptor: String?) -> Void) {
        Database.database().reference().child("allUsers").child(withIdentifier).observeSingleEvent(of: .value, with: { (returnedSnapshot) in
            if let returnedSnapshotAsDictionary = returnedSnapshot.value as? NSDictionary,
               let asData = returnedSnapshotAsDictionary as? [String: Any] {
                var mutableData = asData
                
                mutableData["identifier"] = withIdentifier
                
                self.deSerializeUser(fromData: mutableData) { (returnedUser,
                                                               errorDescriptor) in
                    if let user = returnedUser {
                        completion(user, nil)
                    } else {
                        completion(nil, errorDescriptor ?? "An unknown error occurred.")
                    }
                }
            } else {
                completion(nil, "No user exists with the identifier \"\(withIdentifier)\".")
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
        
        guard let languageCode = fromData["languageCode"] as? String else {
            completion(nil, "Unable to deserialize «languageCode».")
            return
        }
        
        guard let openConversations = fromData["openConversations"] as? [String] else {
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
                                    languageCode: languageCode,
                                    openConversations: openConversations == ["!"] ? nil : openConversations,
                                    phoneNumber: phoneNumber,
                                    region: region)
        
        completion(deSerializedUser, nil)
    }
}
