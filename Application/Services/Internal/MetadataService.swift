//
//  MetadataService.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 27/04/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public struct MetadataService {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Strings
    private(set) static var pushApiKey: String?
    private(set) static var redirectionKey: String?
    
    // Other
    private(set) static var appShareLink: URL?
    private(set) static var appStoreBuildNumber: Int?
    private(set) static var shouldForceUpdate: Bool?
    
    //==================================================//
    
    /* MARK: - Public Methods */
    
    public static func setKeys(completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        var exceptions = [Exception]()
        
        setAppShareLink { exception in
            if let exception {
                exceptions.append(exception)
            }
            
            setAppStoreBuildNumber { exception in
                if let exception {
                    exceptions.append(exception)
                }
                
                setPushApiKey { exception in
                    if let exception {
                        exceptions.append(exception)
                    }
                    
                    setRedirectionKey { exception in
                        if let exception {
                            exceptions.append(exception)
                        }
                        
                        setShouldForceUpdate { exception in
                            if let exception {
                                exceptions.append(exception)
                            }
                            
                            completion(exceptions.isEmpty ? nil : exceptions.compiledException)
                        }
                    }
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Getter Methods */
    
    private static func getAppShareLink(completion: @escaping(_ link: URL?,
                                                              _ exception: Exception?) -> Void) {
        GeneralSerializer.getValues(atPath: "/shared/appShareLink") { values, exception in
            guard let linkString = values as? String,
                  let url = URL(string: linkString) else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(url, nil)
        }
    }
    
    private static func getAppStoreBuildNumber(completion: @escaping(_ buildNumber: Int?,
                                                                     _ exception: Exception?) -> Void) {
        GeneralSerializer.getValues(atPath: "/shared/appStoreBuildNumber") { values, exception in
            guard let buildNumber = values as? Int else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(buildNumber, nil)
        }
    }
    
    private static func getPushApiKey(completion: @escaping(_ key: String?,
                                                            _ exception: Exception?) -> Void) {
        GeneralSerializer.getValues(atPath: "/shared/pushApiKey") { values, exception in
            guard let key = values as? String else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(key, nil)
        }
    }
    
    private static func getRedirectionKey(completion: @escaping(_ key: String?,
                                                                _ exception: Exception?) -> Void) {
        GeneralSerializer.getValues(atPath: "/shared/redirectionKey") { values, exception in
            guard let key = values as? String else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(key, nil)
        }
    }
    
    private static func getShouldForceUpdate(completion: @escaping(_ forceUpdate: Bool?,
                                                                   _ exception: Exception?) -> Void) {
        GeneralSerializer.getValues(atPath: "/shared/shouldForceUpdate") { values, exception in
            guard let forceUpdate = values as? Bool else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(forceUpdate, nil)
        }
    }
    
    //==================================================//
    
    /* MARK: - Setter Methods */
    
    private static func setAppShareLink(completion: @escaping(_ exception: Exception?) -> Void) {
        guard appShareLink == nil else {
            completion(nil)
            return
        }
        
        getAppShareLink { link, exception in
            guard let link else {
                completion(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            self.appShareLink = link
            completion(nil)
        }
    }
    
    private static func setAppStoreBuildNumber(completion: @escaping(_ exception: Exception?) -> Void) {
        guard appStoreBuildNumber == nil else {
            completion(nil)
            return
        }
        
        getAppStoreBuildNumber { buildNumber, exception in
            guard let buildNumber else {
                completion(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            self.appStoreBuildNumber = buildNumber
            completion(nil)
        }
    }
    
    private static func setPushApiKey(completion: @escaping(_ exception: Exception?) -> Void) {
        guard pushApiKey == nil else {
            completion(nil)
            return
        }
        
        getPushApiKey { key, exception in
            guard let key else {
                completion(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            self.pushApiKey = key
            completion(nil)
        }
    }
    
    private static func setRedirectionKey(completion: @escaping(_ exception: Exception?) -> Void) {
        guard redirectionKey == nil else {
            completion(nil)
            return
        }
        
        getRedirectionKey { key, exception in
            guard let key else {
                completion(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            self.redirectionKey = key
            completion(nil)
        }
    }
    
    private static func setShouldForceUpdate(completion: @escaping(_ exception: Exception?) -> Void) {
        guard shouldForceUpdate == nil else {
            completion(nil)
            return
        }
        
        getShouldForceUpdate { forceUpdate, exception in
            guard let forceUpdate else {
                completion(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            self.shouldForceUpdate = forceUpdate
            completion(nil)
        }
    }
}
