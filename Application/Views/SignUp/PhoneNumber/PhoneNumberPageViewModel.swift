//
//  PhoneNumberPageViewModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import Firebase
import PhoneNumberKit

public class PhoneNumberPageViewModel: ObservableObject {
    
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
                          "subtitle": TranslationInput("Please enter your phone number to begin setup. A verification code will be sent to your number. Standard messaging rates apply."),
                          "instruction": TranslationInput("Enter your phone number below:"),
                          "continue": TranslationInput("Continue"),
                          "back": TranslationInput("Back", alternate: "Go back")]
    
    @Published private(set) var state = State.idle
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
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
                                                         _ returnedError: Error?) -> Void) {
        PhoneAuthProvider.provider().verifyPhoneNumber(string,
                                                       uiDelegate: nil) { (returnedIdentifier,
                                                                           returnedError) in
            completion(returnedIdentifier, returnedError)
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


