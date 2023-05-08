//
//  InviteService.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 25/03/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

/* Third-party Frameworks */
import AlertKit
import Translator

public struct InviteService {
    
    //==================================================//
    
    /* MARK: - Public Methods */
    
    public static func askToTranslate(completion: @escaping(_ shouldTranslate: Bool?) -> Void) {
        var message = "Would you like *Hello* to translate the invitation message into another language?"
        if RuntimeStorage.languageCode! == "en" {
            message = message.removingOccurrences(of: ["*"])
        }
        
        let actions = [AKAction(title: "Yes, translate",
                                style: .preferred),
                       AKAction(title: "No, don't translate",
                                style: .default)]
        
        let translationAlert = AKAlert(title: "Translate Invitation",
                                       message: message,
                                       actions: actions,
                                       networkDependent: true)
        
        translationAlert.present { actionID in
            guard actionID != -1 else {
                RuntimeStorage.store(false, as: .wantsToInvite)
                completion(nil)
                return
            }
            
            if actionID == actions[0].identifier {
                completion(true)
            } else if actionID == actions[1].identifier {
                completion(false)
            }
        }
    }
    
    public static func composeInvitation() {
        guard let appShareLink = MetadataService.appShareLink else {
            MetadataService.setKeys { exception in
                guard exception == nil else {
                    Logger.log(exception!, with: .errorAlert)
                    return
                }
                
                self.composeInvitation()
            }
            
            return
        }
        
        let invitationPrompt = "Hey, let's chat on *\"Hello\"*! It's a simple messaging app that allows us to easily talk to each other in our native languages!"
        
        let languageCode = RuntimeStorage.invitationLanguageCode ?? RuntimeStorage.languageCode!
        FirebaseTranslator.shared.translate(Translator.TranslationInput(invitationPrompt),
                                            with: Translator.LanguagePair(from: "en",
                                                                          to: languageCode),
                                            requiresHUD: true) { returnedTranslation, exception in
            RuntimeStorage.remove(.invitationLanguageCode)
            
            guard let translation = returnedTranslation else {
                Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                           with: .errorAlert)
                return
            }
            
            AnalyticsService.logEvent(.invite)
            MessageComposer.shared.compose(withContent: "\(translation.output.removingOccurrences(of: ["*"]))\n\n\(appShareLink.absoluteString)")
        }
    }
}
