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
