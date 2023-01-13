//
//  PermissionsPageViewModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 03/01/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit
import UserNotifications

/* Third-party Frameworks */
import Translator
import Contacts

public class PermissionsPageViewModel: ObservableObject {
    
    //==================================================//
    
    /* MARK: - Enums */
    
    public enum State {
        case idle
        case loading
        case failed(Exception)
        case loaded(translations: [String: Translation])
    }
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private let inputs = ["title": TranslationInput("Grant Permissions"),
                          "subtitle": TranslationInput("Finally, grant *Hello* the necessary permissions to work with your device.\n\nThese options can be changed later in Settings."),
                          "contactPrompt": TranslationInput("Tap to allow contact access"),
                          "notificationPrompt": TranslationInput("Tap to allow notifications"),
                          "finish": TranslationInput("Finish"),
                          "back": TranslationInput("Back", alternate: "Go back")]
    
    @Published private(set) var state = State.idle
    
    //==================================================//
    
    /* MARK: - Initializer Method */
    
    public func load() {
        state = .loading
        
        let dataModel = PageViewDataModel(inputs: inputs)
        
        dataModel.translateStrings { (returnedTranslations,
                                      returnedException) in
            guard let translations = returnedTranslations else {
                let exception = returnedException ?? Exception(metadata: [#file, #function, #line])
                Logger.log(exception)
                
                self.state = .failed(exception)
                return
            }
            
            self.state = .loaded(translations: translations)
        }
    }
    
    //==================================================//
    
    /* MARK: - Authorization Requesting */
    
    public func requestContactPermission(completion: @escaping(_ granted: Bool?,
                                                               _ exception: Exception?) -> Void) {
        CNContactStore().requestAccess(for: .contacts) { granted, error in
            guard error == nil else {
                let exception = Exception(error!, metadata: [#file, #function, #line])
                if exception.isEqual(to: .cnContactStoreAccessDenied) {
                    completion(false, nil)
                } else {
                    completion(nil, Exception(error!, metadata: [#file, #function, #line]))
                }
                
                return
            }
            
            if granted {
                if let archivedHashes = UserDefaults.standard.value(forKey: "archivedLocalUserHashes") as? [String] {
                    RuntimeStorage.store(archivedHashes, as: .archivedLocalUserHashes)
                } else {
                    ContactService.getLocalUserHashes { hashes, exception in
                        guard let hashes else {
                            completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                            return
                        }
                        
                        UserDefaults.standard.set(hashes, forKey: "archivedLocalUserHashes")
                        RuntimeStorage.store(hashes, as: .archivedLocalUserHashes)
                    }
                }
            }
            
            completion(granted, nil)
        }
    }
    
    public func requestNotificationPermission(completion: @escaping(_ granted: Bool?,
                                                                    _ exception: Exception?) -> Void) {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            guard error == nil else {
                completion(nil, Exception(error!, metadata: [#file, #function, #line]))
                return
            }
            
            completion(granted, nil)
        }
        
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    //==================================================//
    
    /* MARK: - Other Methods */
    
    public func createUser(identifier: String,
                           phoneNumber: String,
                           region: String,
                           completion: @escaping(_ exception: Exception?) -> Void) {
        let callingCode = RegionDetailServer.getCallingCode(forRegion: region)
        let pushToken = RuntimeStorage.pushToken
        
        UserSerializer.shared.createUser(identifier,
                                         callingCode: callingCode ?? "1",
                                         languageCode: RuntimeStorage.languageCode!,
                                         phoneNumber: phoneNumber,
                                         pushTokens: pushToken == nil ? nil : [pushToken!],
                                         region: region) { (exception) in
            guard exception == nil else {
                completion(exception!)
                return
            }
            
            completion(nil)
        }
    }
}
