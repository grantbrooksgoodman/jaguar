//
//  DevModeActions.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 07/03/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

/* Third-party Frameworks */
import AlertKit
import Translator

/**
 Use this extension to add actions to the Developer Mode menu.
 */
public extension DevModeService {
    
    //==================================================//
    
    /* MARK: - Standard Action Addition Method */
    
    static func addStandardActions() {
        let clearCachesAction = DevModeAction(title: "Clear Caches", perform: clearCaches)
        let resetUserDefaultsAction = DevModeAction(title: "Reset UserDefaults", perform: resetUserDefaults)
        let switchEnvironmentAction = DevModeAction(title: "Switch Environment", perform: switchEnvironment)
        let overrideLanguageCodeAction = DevModeAction(title: "Override Language Code", perform: overrideLanguageCode)
        
        let destroyConversationDatabaseAction = DevModeAction(title: "Destroy Conversation Database",
                                                              perform: destroyConversationDatabase,
                                                              isDestructive: true)
        let disableDeveloperModeAction = DevModeAction(title: "Disable Developer Mode",
                                                       perform: promptToToggle,
                                                       isDestructive: true)
        
        let standardActions = [clearCachesAction,
                               resetUserDefaultsAction,
                               switchEnvironmentAction,
                               overrideLanguageCodeAction,
                               destroyConversationDatabaseAction,
                               disableDeveloperModeAction]
        addActions(standardActions)
    }
    
    //==================================================//
    
    /* MARK: - Action Handlers */
    
    private static func clearCaches() {
        ContactArchiver.clearArchive()
        ContactService.clearCache()
        ConversationArchiver.clearArchive()
        RecognitionService.clearCache()
        RegionDetailServer.clearCache()
        TranslationArchiver.clearArchive()
        Core.hud.showSuccess(text: "Cleared Caches")
    }
    
    private static func destroyConversationDatabase() {
        AKConfirmationAlert(title: "Destroy Database",
                            message: "This will delete all conversations for all users in the \(GeneralSerializer.environment.description.uppercased()) environment.\n\nThis operation cannot be undone.",
                            confirmationStyle: .destructivePreferred).present { confirmed in
            guard confirmed == 1 else { return }
            AKConfirmationAlert(title: "Are you sure?",
                                message: "ALL CONVERSATIONS FOR ALL USERS WILL BE DELETED!",
                                cancelConfirmTitles: (cancel: nil, confirm: "Yes, I'm sure"),
                                confirmationStyle: .destructivePreferred).present { doubleConfirmed in
                guard doubleConfirmed == 1 else { return }
                ConversationTestingSerializer.deleteAllConversations { exception in
                    guard exception == nil else {
                        Logger.log(exception!, with: .errorAlert)
                        return
                    }
                    
#if !EXTENSION
                    RuntimeStorage.conversationsPageViewModel?.load(silent: false)
#endif
                }
            }
        }
    }
    
    private static func overrideLanguageCode() {
        let languageCodePrompt = AKTextFieldAlert(title: "Override Language Code",
                                                  message: "Enter the two-letter code of the language to apply:",
                                                  actions: [AKAction(title: "Done", style: .preferred)],
                                                  textFieldAttributes: [.placeholderText: "en",
                                                                        .capitalizationType: UITextAutocapitalizationType.none,
                                                                        .correctionType: UITextAutocorrectionType.no,
                                                                        .textAlignment: NSTextAlignment.center],
                                                  shouldTranslate: [.none],
                                                  networkDependent: true)
        
        languageCodePrompt.present { returnedString, actionID in
            guard actionID != -1 else { return }
            guard let returnedString,
                  returnedString.lowercasedTrimmingWhitespace != "" else {
                AKConfirmationAlert(title: "Override Language Code",
                                    message: "No input was entered.\n\nWould you like to try again?",
                                    cancelConfirmTitles: (cancel: nil, confirm: "Try Again"),
                                    confirmationStyle: .preferred,
                                    shouldTranslate: [.none]).present { confirmed in
                    guard confirmed == 1 else { return }
                    self.overrideLanguageCode()
                }
                
                return
            }
            
            guard let languageCodes = RuntimeStorage.languageCodeDictionary,
                  languageCodes.keys.contains(returnedString.lowercasedTrimmingWhitespace) else {
                AKConfirmationAlert(title: "Override Language Code",
                                    message: "The language code entered was invalid. Please try again.",
                                    cancelConfirmTitles: (cancel: nil, confirm: "Try Again"),
                                    confirmationStyle: .preferred,
                                    shouldTranslate: [.none]).present { confirmed in
                    guard confirmed == 1 else { return }
                    self.overrideLanguageCode()
                }
                
                return
            }
            
            RuntimeStorage.store(returnedString, as: .languageCode)
            RuntimeStorage.store(returnedString, as: .overriddenLanguageCode)
            
            defer { Core.hud.showSuccess() }
            
            guard !AKCore.shared.languageCodeIsLocked else {
                AKCore.shared.unlockLanguageCode(andSetTo: returnedString)
                return
            }
            
            AKCore.shared.lockLanguageCode(to: returnedString)
        }
    }
    
    private static func resetUserDefaults() {
        UserDefaults.reset()
        UserDefaults.standard.set(true, forKey: "developerModeEnabled")
        Core.hud.showSuccess(text: "Reset UserDefaults")
    }
    
    private static func switchEnvironment() {
        var actions: [AKAction]!
        
        let firebaseEnvironment = GeneralSerializer.environment
        if firebaseEnvironment == .production {
            actions = [AKAction(title: "Switch to Staging", style: .default),
                       AKAction(title: "Switch to Development", style: .default)]
        } else if firebaseEnvironment == .staging {
            actions = [AKAction(title: "Switch to Production", style: .destructive),
                       AKAction(title: "Switch to Development", style: .default)]
        } else if firebaseEnvironment == .development {
            actions = [AKAction(title: "Switch to Production", style: .destructive),
                       AKAction(title: "Switch to Staging", style: .default)]
        }
        
        var environment = firebaseEnvironment.description
        
        let actionSheet = AKActionSheet(message: "Switch from \(environment) Environment",
                                        actions: actions,
                                        shouldTranslate: [.none])
        
        actionSheet.present { actionID in
            switch firebaseEnvironment {
            case .production:
                GeneralSerializer.environment = actionID == actions[0].identifier ? .staging : .development
            case .staging:
                GeneralSerializer.environment = actionID == actions[0].identifier ? .production : .development
            case .development:
                GeneralSerializer.environment = actionID == actions[0].identifier ? .production : .staging
            }
            
            guard actionID != -1 else { return }
            
            ContactArchiver.clearArchive()
            ConversationArchiver.clearArchive()
            TranslationArchiver.clearArchive()
            
            UserDefaults.reset()
            
            environment = GeneralSerializer.environment.description
            
            AKAlert(message: "Switched to \(environment) environment. You must now restart the app.",
                    actions: [AKAction(title: "Exit", style: .destructivePreferred)],
                    showsCancelButton: false,
                    shouldTranslate: [.none]).present { _ in
                UserDefaults.standard.set(true, forKey: "developerModeEnabled")
                UserDefaults.standard.set(GeneralSerializer.environment.shortString, forKey: "firebaseEnvironment")
                
                fatalError()
            }
        }
    }
}
