//
//  UserSerializer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 01/05/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public struct UserSerializer {
    
    //==================================================//
    
    /* MARK: - Functions */
    
    public static func createUser(_ identifier: String,
                                  phoneNumber: Int,
                                  languageCode: String,
                                  completion: @escaping(_ errorDescriptor: String?) -> Void) {
        let dataBundle = ["phoneNumber": String(phoneNumber),
                          "languageCode": languageCode]
        
        GeneralSerializer.shared.updateValue(onKey: "/allUsers/\(identifier)",
                                             withData: dataBundle) { (returnedError) in
            if let error = returnedError {
                completion(errorInfo(error))
            } else {
                completion(nil)
            }
        }
    }
}
