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
        let restoreResetOnFirstRunFlag = DevModeAction(title: "Restore “Reset on First Run” Flag", perform: restoreResetOnFirstRunFlag)
        
        let destroyConversationDatabaseAction = DevModeAction(title: "Destroy Conversation Database",
                                                              perform: destroyConversationDatabase,
                                                              isDestructive: true)
        let resetPushTokensAction = DevModeAction(title: "Reset Push Tokens",
                                                  perform: resetPushTokens,
                                                  isDestructive: true)
        let disableDeveloperModeAction = DevModeAction(title: "Disable Developer Mode",
                                                       perform: promptToToggle,
                                                       isDestructive: true)
        
        let standardActions = [clearCachesAction,
                               resetUserDefaultsAction,
                               switchEnvironmentAction,
                               overrideLanguageCodeAction,
                               restoreResetOnFirstRunFlag,
                               destroyConversationDatabaseAction,
                               resetPushTokensAction,
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
        let previousLanguage = RuntimeStorage.languageCode!
        AKCore.shared.lockLanguageCode(to: "en")
        AKConfirmationAlert(title: "Destroy Database",
                            message: "This will delete all conversations for all users in the \(GeneralSerializer.environment.description.uppercased()) environment.\n\nThis operation cannot be undone.",
                            confirmationStyle: .destructivePreferred).present { confirmed in
            AKCore.shared.unlockLanguageCode(andSetTo: previousLanguage)
            guard confirmed == 1 else { return }
            AKCore.shared.lockLanguageCode(to: "en")
            AKConfirmationAlert(title: "Are you sure?",
                                message: "ALL CONVERSATIONS FOR ALL USERS WILL BE DELETED!",
                                cancelConfirmTitles: (cancel: nil, confirm: "Yes, I'm sure"),
                                confirmationStyle: .destructivePreferred).present { doubleConfirmed in
                AKCore.shared.unlockLanguageCode(andSetTo: previousLanguage)
                guard doubleConfirmed == 1 else { return }
                ConversationTestingSerializer.deleteAllConversations { exception in
                    guard exception == nil else {
                        Logger.log(exception!, with: .errorAlert)
                        return
                    }
                    
                    Core.hud.showSuccess()
#if !EXTENSION
                    RuntimeStorage.conversationsPageViewModel?.load(silent: false)
#endif
                }
            }
        }
    }
    
    private static func overrideLanguageCode() {
        AKCore.shared.lockLanguageCode(to: "en")
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
            AKCore.shared.unlockLanguageCode()
            guard actionID != -1 else { return }
            guard let returnedString,
                  returnedString.lowercasedTrimmingWhitespace != "" else {
                AKCore.shared.lockLanguageCode(to: "en")
                AKConfirmationAlert(title: "Override Language Code",
                                    message: "No input was entered.\n\nWould you like to try again?",
                                    cancelConfirmTitles: (cancel: nil, confirm: "Try Again"),
                                    confirmationStyle: .preferred,
                                    shouldTranslate: [.none]).present { confirmed in
                    AKCore.shared.unlockLanguageCode()
                    guard confirmed == 1 else { return }
                    self.overrideLanguageCode()
                }
                
                return
            }
            
            guard let languageCodes = RuntimeStorage.languageCodeDictionary,
                  languageCodes.keys.contains(returnedString.lowercasedTrimmingWhitespace) else {
                AKCore.shared.lockLanguageCode(to: "en")
                AKConfirmationAlert(title: "Override Language Code",
                                    message: "The language code entered was invalid. Please try again.",
                                    cancelConfirmTitles: (cancel: nil, confirm: "Try Again"),
                                    confirmationStyle: .preferred,
                                    shouldTranslate: [.none]).present { confirmed in
                    AKCore.shared.unlockLanguageCode()
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
    
    private static func resetPushTokens() {
        let previousLanguage = RuntimeStorage.languageCode!
        AKCore.shared.lockLanguageCode(to: "en")
        AKConfirmationAlert(title: "Reset Push Tokens",
                            message: "This will remove all push tokens for all users in the \(GeneralSerializer.environment.description.uppercased()) environment.\n\nThis operation cannot be undone.",
                            confirmationStyle: .destructivePreferred,
                            shouldTranslate: [.none],
                            networkDependent: true).present { confirmed in
            defer { AKCore.shared.unlockLanguageCode(andSetTo: previousLanguage) }
            
            guard confirmed == 1 else { return }
            UserTestingSerializer.shared.resetPushTokensForAllUsers { exception in
                guard exception == nil else {
                    Logger.log(exception!, with: .errorAlert)
                    return
                }
                
                Core.hud.flash("Reset Push Tokens", image: .success)
            }
        }
    }
    
    private static func resetUserDefaults() {
        UserDefaults.reset()
        UserDefaults.standard.set(true, forKey: "developerModeEnabled")
        Core.hud.showSuccess(text: "Reset UserDefaults")
    }
    
    private static func restoreResetOnFirstRunFlag() {
        RuntimeStorage.store(false, as: .didResetForFirstRun)
        UserDefaults.standard.set(false, forKey: "didResetForFirstRun")
        Core.hud.flash("App will reset on next launch", image: .success)
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
        
        let previousLanguage = RuntimeStorage.languageCode!
        AKCore.shared.lockLanguageCode(to: "en")
        actionSheet.present { actionID in
            guard actionID != -1 else {
                AKCore.shared.unlockLanguageCode(andSetTo: previousLanguage)
                return
            }
            
            switch firebaseEnvironment {
            case .production:
                GeneralSerializer.environment = actionID == actions[0].identifier ? .staging : .development
            case .staging:
                GeneralSerializer.environment = actionID == actions[0].identifier ? .production : .development
            case .development:
                GeneralSerializer.environment = actionID == actions[0].identifier ? .production : .staging
            }
            
            UserDefaults.reset()
            ContactArchiver.clearArchive()
            ContactService.clearCache()
            ConversationArchiver.clearArchive()
            RecognitionService.clearCache()
            RegionDetailServer.clearCache()
            TranslationArchiver.clearArchive()
            
            environment = GeneralSerializer.environment.description
            UserDefaults.standard.set(true, forKey: "developerModeEnabled")
            UserDefaults.standard.set(GeneralSerializer.environment.shortString, forKey: "firebaseEnvironment")
            
            AKAlert(message: "Switched to \(environment) environment. You must now restart the app.",
                    actions: [AKAction(title: "Exit", style: .destructivePreferred)],
                    showsCancelButton: false,
                    shouldTranslate: [.none]).present { _ in
                AKCore.shared.unlockLanguageCode(andSetTo: previousLanguage)
                fatalError()
            }
        }
    }
}
