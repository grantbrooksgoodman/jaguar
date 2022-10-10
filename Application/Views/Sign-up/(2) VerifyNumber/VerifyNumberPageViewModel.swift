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
    
    /* MARK: - Enums */
    
    public enum State {
        case idle
        case loading
        case failed(String)
        case loaded(translations: [String: Translation])
    }
    
    //==================================================//
    
    /* MARK: - Properties */
    
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
    
    public func verifyPhoneNumber(_ string: String,
                                  completion: @escaping (_ returnedIdentifier: String?,
                                                         _ errorDescriptor: String?) -> Void) {
        Auth.auth().languageCode = RuntimeStorage.languageCode!
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
        UserSerializer.shared.validUsers(forPhoneNumbers: [phoneNumber]) { returnedUsers, errorDescriptor in
            if returnedUsers == nil || returnedUsers?.count == 0 {
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
                RuntimeStorage.store(RuntimeStorage.languageCode!, as: .previousLanguageCode)
                RuntimeStorage.store(returnedUsers![0].languageCode!, as: .languageCode)
                
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


