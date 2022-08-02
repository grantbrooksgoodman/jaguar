//
//  ReportProvider.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 01/08/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import AlertKit
import Translator

public class ReportProvider: AKReportProvider {
    
    //==================================================//
    
    /* MARK: - Protocol Compliance Function */
    
    public func fileReport(type: ReportType,
                           body: String,
                           prompt: String,
                           extraInfo: String?,
                           metadata: [Any]) {
        var translatedBody = body
        var translatedPrompt = prompt
        
        FirebaseTranslator.shared.getTranslations(for: [Translator.TranslationInput(body),
                                                        Translator.TranslationInput(prompt)],
                                                  languagePair: Translator.LanguagePair(from: "en",
                                                                                        to: languageCode),
                                                  requiresHUD: true,
                                                  using: .google) { (returnedTranslations,
                                                                     errorDescriptors) in
            guard let translations = returnedTranslations else {
                Logger.log(errorDescriptors?.keys.joined(separator: "\n") ?? "An unknown error occurred.",
                           metadata: [#file, #function, #line])
                return
            }
            
            translatedBody = translations.first(where: { $0.input.value() == translatedBody })?.output ?? translatedBody
            translatedPrompt = translations.first(where: { $0.input.value() == translatedPrompt })?.output ?? translatedPrompt
            
            guard AKCore.shared.validateMetadata(metadata) else {
                Logger.log("Improperly formatted metadata.",
                           metadata: [#file, #function, #line])
                return
            }
            
            guard let code = AKCore.shared.code(for: type, metadata: metadata) else {
                Logger.log("Unable to generate code.",
                           with: .fatalAlert,
                           metadata: [#file, #function, #line])
                return
            }
            
            let connectionStatus = hasConnectivity() ? "online" : "offline"
            
            let bodySection = translatedBody.split(separator: ".").count > 1 ? "<i>\(translatedBody.split(separator: ".")[0]).<p></p>\(translatedBody.split(separator: ".")[1]).</i><p></p>" : "<i>\(translatedBody.split(separator: ".")[0]).</i><p></p>"
            
            let compiledRemainder = "<b>Project ID:</b> \(informationDictionary["projectIdentifier"]!)<p></p><b>Build SKU:</b> \(informationDictionary["buildSku"]!)<p></p><b>Occurrence Date:</b> \(secondaryDateFormatter.string(from: Date()))<p></p><b>Internet Connection Status:</b> \(connectionStatus)<p></p>\(extraInfo == nil ? "" : "<b>Extraneous Information:</b> \(extraInfo!)<p></p>")<b>Reference Code:</b> [\(code)]<p></p><b>\(translatedPrompt):</b> "
            
            let subject = "\(buildType == .generalRelease ? finalName : codeName) (\(informationDictionary["bundleVersion"]!)) \(type == .bug ? "Bug" : (type == .error ? "Error" : "Feedback")) Report"
            
            composeMessage(bodySection + compiledRemainder,
                           recipients: ["me@grantbrooks.io"],
                           subject: subject,
                           isHTML: true,
                           metadata: metadata)
        }
    }
}
