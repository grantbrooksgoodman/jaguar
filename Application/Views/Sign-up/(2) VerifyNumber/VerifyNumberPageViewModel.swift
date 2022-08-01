//
//  VerifyNumberPageViewModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import Firebase
import FirebaseAuth
import PhoneNumberKit
import Translator

public class VerifyNumberPageViewModel: ObservableObject {
    
    //==================================================//
    
    /* MARK: - Enumerated Type Declarations */
    
    public enum State {
        case idle
        case loading
        case failed(String)
        case loaded(translations: [String: Translation])
    }
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    //Other Declarations
    private let inputs = ["title": TranslationInput("Enter Phone Number"),
                          "subtitle": TranslationInput("Next, enter your phone number with your country prefix.\n\nA verification code will be sent to your number. Standard messaging rates apply."),
                          "instruction": TranslationInput("Enter your phone number below:"),
                          "continue": TranslationInput("Continue"),
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
    
    public func simpleErrorString(_ errorDescriptor: String) -> String {
        switch errorDescriptor {
        case "Invalid format.", "The format of the phone number provided is incorrect. Please enter the phone number in a format that can be parsed into E.164 format. E.164 phone numbers are written in the format [+][country code][subscriber number including area code].", "TOO_SHORT":
            return "The format of the phone number provided is incorrect.\n\nPlease verify that you have fully entered your phone number, including the country and area codes."
        case "The SMS verification code used to create the phone auth credential is invalid. Please resend the verification code sms and be sure use the verification code provided by the user.":
            return "The verification code entered was invalid. Please try again."
        case "We have blocked all requests from this device due to unusual activity. Try again later.":
            return "Due to unusual activity, all requests from this device have been temporarily blocked. Please try again later."
        default:
            return "An unknown error has occurred. Please try again."
        }
    }
    
    public func verifyPhoneNumber(_ string: String,
                                  completion: @escaping (_ returnedIdentifier: String?,
                                                         _ errorDescriptor: String?) -> Void) {
        Auth.auth().languageCode = languageCode
        PhoneAuthProvider.provider().verifyPhoneNumber(string,
                                                       uiDelegate: nil) { (returnedIdentifier,
                                                                           returnedError) in
            completion(returnedIdentifier,
                       returnedError == nil ? nil : Logger.errorInfo(returnedError!))
        }
    }
    
    public func verifyUser(phoneNumber: String,
                           completion: @escaping (_ returnedIdentifier: String?,
                                                  _ errorDescriptor: String?,
                                                  _ hasAccount: Bool) -> Void) {
        UserSerializer.shared.findUser(byPhoneNumber: phoneNumber) { (returnedUser, _) in
            if returnedUser == nil {
                self.verifyPhoneNumber("+\(phoneNumber)") { (returnedIdentifier,
                                                             errorDescriptor) in
                    guard let identifier = returnedIdentifier else {
                        completion(nil,
                                   errorDescriptor ?? "An unknown error occurred.",
                                   false)
                        return
                    }
                    
                    completion(identifier,
                               nil,
                               false)
                }
            } else {
                previousLanguageCode = languageCode
                languageCode = returnedUser!.languageCode
                
                completion(nil,
                           nil,
                           true)
            }
        }
    }
}

//==================================================//

/* MARK: Extensions */

/**/

/* MARK: String */
extension String {
    var digitalValue: Int? {
        return Int(components(separatedBy: CharacterSet.decimalDigits.inverted).joined(separator: ""))
    }
}


