//
//  SignInPageViewModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 30/06/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import Firebase
import FirebaseAuth
import Translator

public class SignInPageViewModel: ObservableObject {
    
    //==================================================//
    
    /* MARK: - Enums */
    
    public enum State {
        case idle
        case loading
        case failed(String)
        case loaded(translations: [String: Translation])
    }
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private let inputs = ["phoneNumberPrompt": TranslationInput("Enter your phone number below:"),
                          "codePrompt": TranslationInput("Enter the code sent to your device:"),
                          "continue": TranslationInput("Continue"),
                          "finish": TranslationInput("Finish"),
                          "back": TranslationInput("Back", alternate: "Go back")]
    
    @Published private(set) var state = State.idle
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
    public func load() {
        state = .loading
        
        let dataModel = PageViewDataModel(inputs: inputs)
        
        dataModel.translateStrings { (returnedTranslations,
                                      errorDescriptor) in
            guard let translations = returnedTranslations else {
                let error = errorDescriptor ?? "An unknown error occurred."
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                
                self.state = .failed(error)
                return
            }
            
            self.state = .loaded(translations: translations)
        }
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
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
    
    public func verifyPhoneNumber(_ string: String,
                                  completion: @escaping (_ returnedIdentifier: String?,
                                                         _ returnedError: Error?) -> Void) {
        PhoneAuthProvider.provider().verifyPhoneNumber(string,
                                                       uiDelegate: nil) { (returnedIdentifier,
                                                                           returnedError) in
            completion(returnedIdentifier, returnedError)
        }
    }
}
