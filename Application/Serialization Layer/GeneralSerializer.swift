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
     - Parameter timeout: An optional `Timeout` for the operation; defaults to 10 seconds.
     - Parameter completion: Returns the Firebase snapshot value.
     */
    public static func getValues(atPath: String,
                                 timeout: Timeout? = nil,
                                 completion: @escaping(_ values: Any?,
                                                       _ exception: Exception?) -> Void) {
        let timeout = timeout ?? Timeout(after: 10, {
            completion(nil, Exception.timedOut([#file, #function, #line]))
        })
        
        Database.database().reference().child(atPath).observeSingleEvent(of: .value) { snapshot in
            timeout.cancel()
            completion(snapshot.value, nil)
        } withCancel: { error in
            timeout.cancel()
            completion(nil, Exception(error, metadata: [#file, #function, #line]))
        }
    }
    
    //==================================================//
    
    /* MARK: - Query Methods */
    
    public static func queryValues(atPath: String,
                                   limit: Int,
                                   timeout: Timeout? = nil,
                                   completion: @escaping (_ values: Any?,
                                                          _ exception: Exception?) -> Void) {
        let timeout = timeout ?? Timeout(after: 10, {
            completion(nil, Exception.timedOut([#file, #function, #line]))
        })
        
        Database.database().reference().child(atPath).queryLimited(toFirst: UInt(limit)).getData { (error, snapshot) in
            guard let snapshot, let value = snapshot.value else {
                let exception = error == nil ? Exception(metadata: [#file, #function, #line]) : Exception(error!, metadata: [#file, #function, #line])
                timeout.cancel()
                completion(nil, exception)
                return
            }
            
            timeout.cancel()
            completion(value, nil)
        }
    }
    
    //==================================================//
    
    /* MARK: - Setter Methods */
    
    public static func setValue(_ value: Any,
                                forKey key: String,
                                timeout: Timeout? = nil,
                                completion: @escaping(_ exception: Exception?) -> Void) {
        let timeout = timeout ?? Timeout(after: 10, {
            completion(Exception.timedOut([#file, #function, #line]))
        })
        
        Database.database().reference().child(key).setValue(value) { error, _ in
            guard let error else {
                timeout.cancel()
                completion(nil)
                return
            }
            
            timeout.cancel()
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
                                         timeout: Timeout? = nil,
                                         completion: @escaping(_ exception: Exception?) -> Void) {
        let timeout = timeout ?? Timeout(after: 10, {
            completion(Exception.timedOut([#file, #function, #line]))
        })
        
        Database.database().reference().child(key).updateChildValues(data, withCompletionBlock: { error, _ in
            guard let error else {
                timeout.cancel()
                completion(nil)
                return
            }
            
            timeout.cancel()
            completion(Exception(error, metadata: [#file, #function, #line]))
        })
    }
}
