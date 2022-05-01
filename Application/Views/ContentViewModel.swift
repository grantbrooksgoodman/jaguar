//
//  ContentViewModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public class ContentViewModel: ObservableObject {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    public enum State {
        case idle
        case loading
        case failed(String)
        case loaded(String)
    }
    
    @Published private(set) var state = State.idle
    
    //==================================================//
    
    /* MARK: - Functions */
    
    private let text: String
    
    public init(text: String) {
        self.text = text
    }
    
    public func load() {
        state = .loading
        
        TranslatorService.main.translate(TranslationInput("hey what's up"),
                                         with: LanguagePair(from: "en",
                                                            to: languageCode),
                                         requiresHUD: false,
                                         using: .deepL) { [weak self] (returnedTranslation,
                                                                       errorDescriptor) in
            if let translation = returnedTranslation {
                self?.state = .loaded(translation.output)
            } else if let error = errorDescriptor {
                log(error, metadata: [#file, #function, #line])
                self?.state = .failed(error)
            }
        }
    }
}
