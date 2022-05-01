//
//  VerifyInfoPageViewModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

//==================================================//

/* MARK: - Views */

public class VerifyInfoPageViewModel: ObservableObject {
    
    public enum State {
        case idle
        case loading
        case failed(String)
        case loaded(translations: [String: Translation])
    }
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    @Published private(set) var state = State.idle
    
    private let inputs = ["title": TranslationInput("Verify Information"),
                          "subtitle": TranslationInput("Verify your information and press continue to complete setup."),
                          "instruction": TranslationInput("You speak:", alternate: "Language you speak:"),
                          "continue": TranslationInput("Continue"),
                          "back": TranslationInput("Back", alternate: "Go back")]
    
    private var languageNames = [String]()
    
    //==================================================//
    
    /* MARK: - Functions */
    
    public func load() {
        state = .loading
        
        for name in languageCodeDictionary.values {
            languageNames.append(name)
        }
        
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
}
