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
    
    public static var environment: Environment = .production
    
    //==================================================//
    
    /* MARK: - Getter Methods */
    
    /**
     Gets values on the server for a given path.
     
     - Parameter atPath: The server path at which to retrieve values.
     - Parameter completion: Returns the Firebase snapshot value.
     */
    public static func getValues(atPath: String, completion: @escaping (_ values: Any?,
                                                                        _ exception: Exception?) -> Void) {
        Database.database().reference().child(atPath).observeSingleEvent(of: .value) { snapshot in
            completion(snapshot.value, nil)
        } withCancel: { error in
            completion(nil, Exception(error, metadata: [#file, #function, #line]))
        }
    }
    
    //==================================================//
    
    /* MARK: - Query Methods */
    
    public static func queryValues(atPath: String,
                                   limit: Int,
                                   completion: @escaping (_ values: Any?,
                                                          _ exception: Exception?) -> Void) {
        Database.database().reference().child(atPath).queryLimited(toFirst: UInt(limit)).getData { (error, snapshot) in
            guard let snapshot, let value = snapshot.value else {
                let exception = error == nil ? Exception(metadata: [#file, #function, #line]) : Exception(error!, metadata: [#file, #function, #line])
                completion(nil, exception)
                return
            }
            
            completion(value, nil)
        }
    }
    
    //==================================================//
    
    /* MARK: - Setter Methods */
    
    public static func setValue(_ value: Any,
                                forKey key: String,
                                completion: @escaping(_ exception: Exception?) -> Void) {
        Database.database().reference().child(key).setValue(value) { error, _ in
            guard let error else {
                completion(nil)
                return
            }
            
            completion(Exception(error, metadata: [#file, #function, #line]))
        }
    }
    
    /**
     Updates a value on the server for a given key and data bundle.
     
     - Parameter forKey: The server path at which to update child values.
     - Parameter with: The data with which to update the server.
     
     - Parameter completion: Returns an `Exception` if unable to update values.
     */
    public static func updateChildValues(forKey key: String,
                                         with data: [String: Any],
                                         completion: @escaping(_ exception: Exception?) -> Void) {
        Database.database().reference().child(key).updateChildValues(data, withCompletionBlock: { error, _ in
            guard let error else {
                completion(nil)
                return
            }
            
            completion(Exception(error, metadata: [#file, #function, #line]))
        })
    }
    
    
    //==================================================//
    
    /* MARK: - Stored Variable Retrieval */
    
    public static func getAppShareLink(completion: @escaping(_ link: URL?,
                                                             _ exception: Exception?) -> Void) {
        getValues(atPath: "/shared/appShareLink") { values, exception in
            guard let linkString = values as? String,
                  let url = URL(string: linkString) else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(url, nil)
        }
    }
    
    public static func getPushApiKey(completion: @escaping(_ key: String?,
                                                           _ exception: Exception?) -> Void) {
        getValues(atPath: "/shared/pushApiKey") { values, exception in
            guard let key = values as? String else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(key, nil)
        }
    }
    
    public static func getRedirectionKey(completion: @escaping(_ key: String?,
                                                               _ exception: Exception?) -> Void) {
        getValues(atPath: "/shared/redirectionKey") { values, exception in
            guard let key = values as? String else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(key, nil)
        }
    }
}
