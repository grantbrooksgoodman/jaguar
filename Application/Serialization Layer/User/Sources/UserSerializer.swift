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
    
    /* MARK: - Struct-level Variable Declarations */
    
    public static let shared = UserSerializer()
    
    //==================================================//
    
    /* MARK: - Creation Functions */
    
    public func createUser(_ identifier: String,
                           languageCode: String,
                           phoneNumber: String,
                           region: String,
                           completion: @escaping(_ errorDescriptor: String?) -> Void) {
        let data = ["languageCode": languageCode,
                    "phoneNumber": phoneNumber.digits,
                    "region": region,
                    "openConversations": ["!"]] as [String: Any]
        
        GeneralSerializer.updateValue(onKey: "/allUsers/\(identifier)",
                                      withData: data) { (returnedError) in
            guard let error = returnedError else {
                completion(nil)
                return
            }
            
            completion(Logger.errorInfo(error))
        }
    }
    
    //==================================================//
    
    /* MARK: - Retrieval Functions */
    
    public func findUser(byPhoneNumber: String,
                         completion: @escaping(_ returnedUser: User?,
                                               _ errorDescriptor: String?) -> Void) {
        Database.database().reference().child("allUsers").observeSingleEvent(of: .value, with: { (returnedSnapshot) in
            guard let snapshot = returnedSnapshot.value as? NSDictionary,
                  let data = snapshot as? [String: Any] else {
                completion(nil, "No user exists with the provided phone number.")
                return
            }
            
            guard data.count > 0 else {
                completion(nil, "Couldn't get users.")
                return
            }
            
            var found = false
            
            for user in data {
                if var userData = user.value as? [String: Any],
                   let phoneNumberString = userData["phoneNumber"] as? String,
                   phoneNumberString.digits == byPhoneNumber.digits {
                    userData["identifier"] = user.key
                    
                    found = true
                    UserSerializer.shared.deSerializeUser(fromData: userData) { (returnedUser,
                                                                                 errorDescriptor) in
                        guard let foundUser = returnedUser else {
                            completion(nil, errorDescriptor ?? "An unknown error occurred.")
                            return
                        }
                        
                        completion(foundUser, nil)
                    }
                }
            }
            
            if !found {
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
