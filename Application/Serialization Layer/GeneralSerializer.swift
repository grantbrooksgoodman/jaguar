//
//  GeneralSerializer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 17/07/2017.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import UIKit

/* Third-party Frameworks */
import FirebaseDatabase

public enum GeneralSerializer {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public enum Environment: String {
        case development
        case staging
        case production
        
        var description: String { rawValue.firstUppercase }
        var shortString: String {
            switch self {
            case .development:
                return "dev"
            case .staging:
                return "stage"
            case .production:
                return "prod"
            }
        }
    }
    
    public static var environment: Environment = .development
    
    //==================================================//
    
    /* MARK: - Getter Methods */
    
    /**
     Gets values on the server for a given path.
     
     - Parameter atPath: The server path at which to retrieve values.
     - Parameter completion: Returns the Firebase snapshot value.
     */
    public static func getValues(atPath: String, completion: @escaping (_ returnedValues: Any?,
                                                                        _ returnedException: Exception?) -> Void) {
        Database.database().reference().child(atPath).observeSingleEvent(of: .value) { returnedSnapshot in
            completion(returnedSnapshot.value, nil)
        } withCancel: { returnedError in
            completion(nil, Exception(returnedError,
                                      metadata: [#file, #function, #line]))
        }
    }
    
    //==================================================//
    
    /* MARK: - Query Methods */
    
    public static func queryValues(atPath: String,
                                   limit: Int,
                                   completion: @escaping (_ returnedValues: Any?,
                                                          _ exception: Exception?) -> Void) {
        Database.database().reference().child(atPath).queryLimited(toFirst: UInt(limit)).getData { (returnedError, returnedSnapshot) in
            if let error = returnedError {
                completion(nil, Exception(error, metadata: [#file, #function, #line]))
            }
            
            completion(returnedSnapshot?.value, nil)
        }
    }
    
    //==================================================//
    
    /* MARK: - Setter Methods */
    
    public static func setValue(onKey: String, withData: Any, completion: @escaping (Error?) -> Void) {
        Database.database().reference().child(onKey).setValue(withData) { returnedError, _ in
            guard let error = returnedError else {
                completion(nil)
                return
            }
            
            completion(error)
        }
    }
    
    /**
     Updates a value on the server for a given key and data bundle.
     
     - Parameter onKey: The server path at which to update values.
     - Parameter withData: The data bundle to update the server with.
     
     - Parameter completion: Returns an `Error` if unable to update values.
     */
    public static func updateValue(onKey: String, withData: [String: Any], completion: @escaping (Error?) -> Void) {
        Database.database().reference().child(onKey).updateChildValues(withData, withCompletionBlock: { returnedError, _ in
            guard let error = returnedError else {
                completion(nil)
                return
            }
            
            completion(error)
        })
    }
    
    //==================================================//
    
    /* MARK: - Stored Variable Retrieval */
    
    public static func getAppShareLink(completion: @escaping(_ link: URL?,
                                                             _ exception: Exception?) -> Void) {
        getValues(atPath: "/appShareLink") { returnedValues, returnedException in
            guard let linkString = returnedValues as? String,
                  let url = URL(string: linkString) else {
                completion(nil, returnedException ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(url, nil)
        }
    }
    
    public static func getPushApiKey(completion: @escaping(_ key: String?,
                                                           _ exception: Exception?) -> Void) {
        getValues(atPath: "/pushApiKey") { returnedValues, returnedException in
            guard let key = returnedValues as? String else {
                completion(nil, returnedException ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(key, nil)
        }
    }
}
