//
//  SelectLanguagePageViewModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

public class SelectLanguagePageViewModel: ObservableObject {
    
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
    
    private let inputs = ["title": TranslationInput("Select Language"),
                          "subtitle": TranslationInput("To begin, please select your language."),
                          "instruction": TranslationInput("You speak:", alternate: "Language you speak:"),
                          "continue": TranslationInput("Continue"),
                          "back": TranslationInput("Back", alternate: "Go back")]
    
    private var languageNames = [String]()
    
    @Published private(set) var state = State.idle
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
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
            guard let translations = returnedTranslations else {
                let error = errorDescriptors?.keys.joined(separator: "\n") ?? "An unknown error occurred."
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                self.state = .failed(error)
                return
            }
            
            guard let matchedTranslations = translations.matchedTo(self.inputs) else {
                self.state = .failed("Couldn't match translations with inputs.")
                return
            }
            
            self.state = .loaded(translations: matchedTranslations)
        }
    }
}
