//
//  InitialPageViewModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import Translator

public class InitialPageViewModel: ObservableObject {
    
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
    
    private let inputs = ["instruction": TranslationInput("Welcome to Hello. Follow the short instructions to get started."),
                          "continue": TranslationInput("Continue"),
                          "alreadyUse": TranslationInput("I already use this app")]
    
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
}
