//
//  Translatorable.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 30/04/2022.
//  Copyright © 2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public protocol Translatorable {
    func instance() -> Translatorable
    
    func translate(_ text: String,
                   from: String,
                   to: String,
                   using: TranslationPlatform,
                   completion: @escaping(_ returnedString: String?,
                                         _ errorDescriptor: String?) -> Void)
}

public enum TranslationPlatform: CaseIterable {
    case azure
    
    case deepL
    case google
    case yandex
    
    case random
}
