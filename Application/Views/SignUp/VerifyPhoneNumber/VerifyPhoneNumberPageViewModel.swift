//
//  VerifyPhoneNumberPageViewModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 01/05/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

/* Third-party Frameworks */
import Firebase

public class VerifyPhoneNumberPageViewModel: ObservableObject {
    
    public enum State {
        case idle
        case loading
        case failed(String)
        case loaded(translations: [String: Translation])
    }
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    @Published private(set) var state = State.idle
    
    private let inputs = ["title": TranslationInput("Enter Verification Code"),
                          "subtitle": TranslationInput("A verification code was sent to your device. It may take a minute or so to arrive."),
                          "instruction": TranslationInput("Enter the code sent to your device:"),
                          "continue": TranslationInput("Continue"),
                          "back": TranslationInput("Back", alternate: "Go back")]
    
    //==================================================//
    
    /* MARK: - Functions */
    
    public func load() {
        state = .loading
        
        TranslatorService.main.getTranslations(for: Array(inputs.values),
                                               languagePair: LanguagePair(from: "en",
                                                                          to: languageCode),
                                               requiresHUD: false,
                                               using: .google) { (returnedTranslations,
                                                                  errorDescriptors) in
            if let translations = returnedTranslations {
                guard let matchedTranslations = translations.matchedTo(self.inputs) else {
                    self.state = .failed("Couldn't match translations with inputs.")
                    return
                }
                
                self.state = .loaded(translations: matchedTranslations)
            } else if let errors = errorDescriptors {
                log(errors.keys.joined(separator: "\n"),
                    metadata: [#file, #function, #line])
                
                self.state = .failed(errors.keys.joined(separator: "\n"))
            }
        }
    }
    
    public func authenticateUser(identifier: String,
                                 verificationCode: String,
                                 completion: @escaping(_ userID: String?,
                                                       _ returnedError: Error?) -> Void) {
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: identifier,
                                                                 verificationCode: verificationCode)
        
        Auth.auth().signIn(with: credential) { (returnedResult, returnedError) in
            if let result = returnedResult {
                completion(result.user.uid, nil)
            } else if let error = returnedError {
                completion(nil, error)
            }
        }
    }
    
    public func getErrorAlertText(_ errorDescriptor: String) -> String {
        switch errorDescriptor {
        case "The SMS verification code used to create the phone auth credential is invalid. Please resend the verification code SMS and be sure to use the verification code provided by the user.":
            return "The verification code entered was invalid. Please try again."
        default:
            return "An unknown error has occurred. Please try again."
        }
    }
}
