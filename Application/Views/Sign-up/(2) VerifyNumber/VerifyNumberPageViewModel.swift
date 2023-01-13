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


