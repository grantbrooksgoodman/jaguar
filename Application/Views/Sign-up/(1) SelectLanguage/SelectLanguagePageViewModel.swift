//
//  SelectLanguagePageViewModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import AlertKit
import Translator

public class SelectLanguagePageViewModel: ObservableObject {
    
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
    
    private let inputs = ["title": Translator.TranslationInput("Select Language"),
                          "subtitle": Translator.TranslationInput("To begin, please select your language."),
                          "instruction": Translator.TranslationInput("I speak:", alternate: "Language you speak:"),
                          "continue": Translator.TranslationInput("Continue"),
                          "back": Translator.TranslationInput("Back", alternate: "Go back")]
    
    private var languageNames = [String]()
    
    @Published private(set) var state = State.idle
    
    //==================================================//
    
    /* MARK: - Initializer Method */
    
    public func load() {
        state = .loading
        
        for name in RuntimeStorage.languageCodeDictionary!.values {
            languageNames.append(name)
        }
        
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
