//
//  TranslatorService.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import WebKit

public struct TranslatorService {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    public static let main = TranslatorService()
    private var subservices: [TranslationPlatform: Translatorable] = [:]
    
    //==================================================//
    
    /* MARK: - Instantiation Functions */
    
    public init() {
        for platform in TranslationPlatform.allCases {
            register(translator: platform)
        }
    }
    
    /// Will be added to as platform managers are added.
    public mutating func register(translator: TranslationPlatform) {
        switch translator {
        case .deepL:
            subservices[.deepL] = DeepLTranslator()
        case .google:
            subservices[.google] = GoogleTranslator()
        case .yandex:
            subservices[.yandex] = YandexTranslator()
        case .random:
            subservices[.random] = [DeepLTranslator(), GoogleTranslator()].randomElement()!
        default:
            subservices[.azure] = AzureTranslator()
        }
    }
    
    //==================================================//
    
    /* MARK: - Translation Functions */
    
    public func getTranslations(for inputs: [TranslationInput],
                                languagePair: LanguagePair,
                                requiresHUD: Bool? = nil,
                                using: TranslationPlatform? = nil,
                                completion: @escaping(_ returnedTranslations: [Translation]?,
                                                      _ errorDescriptors: [String: TranslationInput]?) -> Void) {
        guard !(languagePair.from == "en" && languagePair.to == "en") else {
            var translations = [Translation]()
            
            for input in inputs {
                let translation = Translation(input: input,
                                              output: input.original,
                                              languagePair: languagePair)
                translations.append(translation)
            }
            
            completion(translations, nil)
            return
        }
        
        let dispatchGroup = DispatchGroup()
        
        var translations = [Translation]()
        var errors = [String: TranslationInput]()
        
        Logger.openStream(metadata: [#file, #function, #line])
        
        for (index, input) in inputs.enumerated() {
            dispatchGroup.enter()
            
            translate(input,
                      with: languagePair,
                      requiresHUD: requiresHUD ?? nil,
                      using: using ?? .google) { (returnedTranslation, errorDescriptor) in
                if let translation = returnedTranslation {
                    translations.append(translation)
                }
                //else
                if let error = errorDescriptor {
                    errors[error] = input
                }
                
                Logger.logToStream("Translated item \(index + 1) of \(inputs.count).",
                                   line: #line)
                
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            Logger.closeStream(message: "All strings should be translated; complete.",
                               onLine: #line)
            
            if translations.count + errors.count == inputs.count {
                completion(translations.count == 0 ? nil : translations,
                           errors.count == 0 ? nil : errors)
            } else {
                Logger.log("Mismatched translation input/output.",
                           with: .fatalAlert,
                           metadata: [#file, #function, #line])
                completion(nil, nil)
            }
        }
    }
    
    public func translate(_ input: TranslationInput,
                          with languagePair: LanguagePair,
                          requiresHUD: Bool? = nil,
                          using: TranslationPlatform? = nil,
                          completion: @escaping(_ returnedTranslation: Translation?,
                                                _ errorDescriptor: String?) -> Void) {
        guard !(languagePair.from == "en" && languagePair.to == "en") else {
            let translation = Translation(input: input,
                                          output: input.original,
                                          languagePair: languagePair)
            
            completion(translation, nil)
            return
        }
        
        //Alternate should NEVER be "".
        guard input.value().lowercasedTrimmingWhitespace != "" else {
            let translation = Translation(input: input,
                                          output: "",
                                          languagePair: languagePair)
            completion(translation, nil)
            return
        }
        
        let deepLSupport = ["bg", "zh", "cs",
                            "da", "nl", "en",
                            "et", "fi", "fr",
                            "de", "el", "hu",
                            "id", "it", "ja",
                            "lv", "lt", "pl",
                            "pt", "ro", "ru",
                            "sk", "sl", "es",
                            "sv", "tr"]
        
        var serviceToUse = using ?? .google
        if (serviceToUse == .deepL || serviceToUse == .random) && !deepLSupport.contains(languagePair.to) {
            serviceToUse = .google
        }
        
        if let archivedTranslation = TranslationArchiver.getFromArchive(input,
                                                                        languagePair: languagePair) {
            completion(archivedTranslation, nil)
            return
        }
        
        if let required = requiresHUD,
           required {
            showProgressHUD()
        }
        
        TranslationSerializer.findTranslation(for: input,
                                              languagePair: languagePair) { (returnedString,
                                                                             errorDescriptor) in
            if let translatedString = returnedString {
                Logger.log("No need to use translator; found uploaded string.",
                           metadata: [#file, #function, #line])
                
                var finalInput = input
                if input.value() == input.alternate {
                    finalInput = TranslationInput(input.alternate!,
                                                  alternate: nil)
                }
                
                let translation = Translation(input: finalInput,
                                              output: translatedString.matchingCapitalization(of: input.value()),
                                              languagePair: languagePair)
                
                TranslationArchiver.addToArchive(translation)
                
                completion(translation, nil)
            } else {
                guard let subservice = subservices[serviceToUse] else {
                    completion(nil, "No such translation service exists.")
                    return
                }
                
                subservice.instance().translate(input.value(),
                                                from: languagePair.from,
                                                to: languagePair.to,
                                                using: serviceToUse,
                                                completion: { (returnedString,
                                                               errorDescriptor) in
                                                    
                                                    guard let string = returnedString else {
                                                        #warning("Account for this")
                                                        completion(nil, errorDescriptor ?? "An unknown error occurred." /*nil*/)
                                                        return
                                                    }
                                                    
                                                    var finalInput = input
                                                    if input.value() == input.alternate {
                                                        finalInput = TranslationInput(input.alternate!,
                                                                                      alternate: nil)
                                                    }
                                                    
                                                    let translation = Translation(input: finalInput,
                                                                                  output: string.matchingCapitalization(of: input.value()),
                                                                                  languagePair: languagePair)
                                                    
                                                    TranslationSerializer.uploadTranslation(translation)
                                                    TranslationArchiver.addToArchive(translation)
                                                    
                                                    completion(translation, nil)
                                                    
                                                    if let required = requiresHUD,
                                                       required {
                                                        hideHUD(delay: 0.2)
                                                    }
                                                })
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    public func removeCookies() {
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            records.forEach { record in
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
            }
        }
    }
}
