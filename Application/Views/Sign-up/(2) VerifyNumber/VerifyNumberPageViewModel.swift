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
import AlertKit
import Firebase
import FirebaseAuth
import PhoneNumberKit
import Translator

public class VerifyNumberPageViewModel: ObservableObject {
    
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
    
    private let inputs = ["title": Translator.TranslationInput("Enter Phone Number"),
                          "subtitle": Translator.TranslationInput("Next, enter your phone number with your country prefix.\n\nA verification code will be sent to your number. Standard messaging rates apply."),
                          "instruction": Translator.TranslationInput("Enter your phone number below:"),
                          "continue": Translator.TranslationInput("Continue"),
                          "back": Translator.TranslationInput("Back", alternate: "Go back")]
    
    @Published private(set) var state = State.idle
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
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
    
    /* MARK: - Other Functions */
    
    public func verifyPhoneNumber(_ string: String,
                                  completion: @escaping (_ returnedIdentifier: String?,
                                                         _ exception: Exception?) -> Void) {
        Auth.auth().languageCode = RuntimeStorage.languageCode!
        PhoneAuthProvider.provider().verifyPhoneNumber(string,
                                                       uiDelegate: nil) { (returnedIdentifier,
                                                                           returnedError) in
            completion(returnedIdentifier,
                       returnedError == nil ? nil : Exception(returnedError!,
                                                              metadata: [#file, #function, #line]))
        }
    }
    
    public func verifyUser(phoneNumber: String,
                           completion: @escaping (_ returnedIdentifier: String?,
                                                  _ exception: Exception?,
                                                  _ hasAccount: Bool) -> Void) {
        UserSerializer.shared.findUsers(forPhoneNumbers: [phoneNumber]) { returnedUsers, exception in
            if returnedUsers == nil || returnedUsers?.count == 0 {
                self.verifyPhoneNumber("+\(phoneNumber)") { (returnedIdentifier,
                                                             exception) in
                    guard let identifier = returnedIdentifier else {
                        completion(nil,
                                   exception ?? Exception(metadata: [#file, #function, #line]),
                                   false)
                        return
                    }
                    
                    completion(identifier,
                               nil,
                               false)
                }
            } else {
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


