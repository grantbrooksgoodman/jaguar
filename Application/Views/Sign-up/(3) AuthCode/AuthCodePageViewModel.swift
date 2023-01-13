//
//  AuthCodePageViewModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 01/05/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import AlertKit
import Firebase
import FirebaseAuth
import Translator

public class AuthCodePageViewModel: ObservableObject {
    
    //==================================================//
    
    /* MARK: - Enums */
    
    public enum State {
        case idle
        case loading
        case failed(Exception)
        case loaded(translations: [String: Translator.Translation])
    }
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private let inputs = ["title": Translator.TranslationInput("Enter Verification Code"),
                          "subtitle": Translator.TranslationInput("A verification code was sent to your device. It may take a minute or so to arrive."),
                          "instruction": Translator.TranslationInput("Enter the code sent to your device:"),
                          "continue": Translator.TranslationInput("Continue"),
                          "back": Translator.TranslationInput("Back", alternate: "Go back")]
    
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
    
    public func authenticateUser(identifier: String,
                                 verificationCode: String,
                                 completion: @escaping(_ userID: String?,
                                                       _ returnedError: Error?) -> Void) {
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: identifier,
                                                                 verificationCode: verificationCode)
        
        Auth.auth().signIn(with: credential) { (returnedResult, returnedError) in
            guard let result = returnedResult else {
                completion(nil, returnedError)
                return
            }
            
            completion(result.user.uid, nil)
        }
    }
}
