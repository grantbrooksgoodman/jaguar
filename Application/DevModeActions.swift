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
        let eraseTemporaryFilesAction = DevModeAction(title: "Erase Temporary Files", perform: eraseTemporaryFiles)
        let resetUserDefaultsAction = DevModeAction(title: "Reset UserDefaults", perform: resetUserDefaults)
        let switchEnvironmentAction = DevModeAction(title: "Switch Environment", perform: switchEnvironment)
        let overrideLanguageCodeAction = DevModeAction(title: "Override Language Code", perform: overrideLanguageCode)
        let changeThemeAction = DevModeAction(title: "Change Theme", perform: changeTheme)
        let toggleBuildInfoOverlayAction = DevModeAction(title: "Show/Hide Build Info Overlay", perform: toggleBuildInfoOverlay)
        let restoreResetOnFirstRunFlagAction = DevModeAction(title: "Restore “Reset on First Run” Flag", perform: restoreResetOnFirstRunFlag)
        
        let presentDestructiveOptionsAction = DevModeAction(title: "Destructive Options",
                                                            perform: presentDestructiveOptions,
                                                            isDestructive: true)
        let disableDeveloperModeAction = DevModeAction(title: "Disable Developer Mode",
                                                       perform: promptToToggle,
                                                       isDestructive: true)
        
        let standardActions = [clearCachesAction,
                               eraseTemporaryFilesAction,
                               resetUserDefaultsAction,
                               switchEnvironmentAction,
                               overrideLanguageCodeAction,
                               changeThemeAction,
                               toggleBuildInfoOverlayAction,
                               restoreResetOnFirstRunFlagAction,
                               presentDestructiveOptionsAction,
                               disableDeveloperModeAction]
        addActions(standardActions)
    }
    
    //==================================================//
    
    /* MARK: - Action Handlers */
    
    private static func changeTheme() {
        var actions = [AKAction]()
        var actionIDs = [Int: String]()
        
        for theme in AppThemes.list {
            let isCurrentTheme = theme.name == ThemeService.currentTheme.name
            let action = AKAction(title: isCurrentTheme ? "\(theme.name) (Applied)" : theme.name, style: .default)
            action.isEnabled = theme.name != ThemeService.currentTheme.name
            actions.append(action)
            actionIDs[action.identifier] = theme.name
        }
        
        AKActionSheet(message: "Change Theme",
                      actions: actions,
                      shouldTranslate: [.none]).present { actionID in
            guard actionID != -1,
                  let themeName = actionIDs[actionID],
                  let correspondingTheme = AppThemes.list.first(where: { $0.name == themeName }) else { return }
            
            ThemeService.setTheme(correspondingTheme, checkStyle: false)
        }
    }
    
    private static func clearCaches() {
        Core.clearCaches()
        Core.hud.showSuccess(text: "Cleared Caches")
    }
    
    private static func eraseTemporaryFiles() {
        guard let exception = Core.eraseTemporaryDirectory() else {
            Core.hud.flash("Erased Temporary Files", image: .success)
            return
        }
        
        let previousLanguage = RuntimeStorage.languageCode!
        setLanguageCode("en")
        AKErrorAlert(error: exception.asAkError()).present { _ in setLanguageCode(previousLanguage) }
    }
    
    private static func overrideLanguageCode() {
        setLanguageCode("en")
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
                setLanguageCode("en")
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
                setLanguageCode("en")
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
            
            setLanguageCode(returnedString)
            Core.hud.showSuccess()
        }
    }
    
    private static func resetUserDefaults() {
        UserDefaults.reset()
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.developerModeEnabledKey)
        Core.hud.showSuccess(text: "Reset UserDefaults")
    }
    
    private static func restoreResetOnFirstRunFlag() {
        RuntimeStorage.store(false, as: .didResetForFirstRun)
        UserDefaults.standard.set(false, forKey: UserDefaultsKeys.didResetForFirstRunKey)
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
        setLanguageCode("en")
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
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.developerModeEnabledKey)
            UserDefaults.standard.set(GeneralSerializer.environment.shortString, forKey: UserDefaultsKeys.firebaseEnvironmentKey)
            
            AKAlert(message: "Switched to \(environment) environment. You must now restart the app.",
                    actions: [AKAction(title: "Exit", style: .destructivePreferred)],
                    showsCancelButton: false,
                    shouldTranslate: [.none]).present { _ in
                AKCore.shared.unlockLanguageCode(andSetTo: previousLanguage)
                fatalError()
            }
        }
    }
    
    private static func toggleBuildInfoOverlay() {
        guard let overlay = RuntimeStorage.topWindow?.subview(Core.ui.nameTag(for: "buildInfoOverlayWindow")) as? UIWindow else { return }
        
        guard !RuntimeStorage.isPresentingChat! else { return }
        
        guard let currentValue = UserDefaults.standard.value(forKey: UserDefaultsKeys.hidesBuildInfoOverlayKey) as? Bool else {
            overlay.isHidden.toggle()
            UserDefaults.standard.set(overlay.isHidden, forKey: UserDefaultsKeys.hidesBuildInfoOverlayKey)
            return
        }
        
        let toggledValue = !currentValue
        overlay.isHidden = toggledValue
        UserDefaults.standard.set(toggledValue, forKey: UserDefaultsKeys.hidesBuildInfoOverlayKey)
    }
    
    //==================================================//
    
    /* MARK: - Destructive Action Handlers */
    
    private static func presentDestructiveOptions() {
        let destroyConversationDatabaseAction = DevModeAction(title: "Destroy Conversation Database",
                                                              perform: destroyConversationDatabase,
                                                              isDestructive: true)
        let eraseDocumentsDirectoryAction = DevModeAction(title: "Erase Documents Directory",
                                                          perform: eraseDocumentsDirectory,
                                                          isDestructive: true)
        let resetPushTokensAction = DevModeAction(title: "Reset Push Tokens",
                                                  perform: resetPushTokens,
                                                  isDestructive: true)
        
        let destructiveActions: [DevModeAction] = [destroyConversationDatabaseAction,
                                                   eraseDocumentsDirectoryAction,
                                                   resetPushTokensAction]
        
        guard let topViewController = UIApplication.topViewController(),
              !topViewController.isKind(of: UIAlertController.self) else { return }
        
        var akActions = [AKAction]()
        for action in destructiveActions {
            akActions.append(AKAction(title: action.title,
                                      style: action.isDestructive ? .destructive : .default))
        }
        
        let actionSheet = AKActionSheet(message: "Destructive Options",
                                        actions: akActions,
                                        shouldTranslate: [.none])
        
        actionSheet.present { actionID in
            guard let index = akActions.firstIndex(where: { $0.identifier == actionID }),
                  index < destructiveActions.count else { return }
            
            let selectedAkAction = akActions[index]
            let presumedDevModeAction = destructiveActions[index]
            
            let akActionTitle = selectedAkAction.title
            let akActionDestructive = selectedAkAction.style == .destructive
            
            guard presumedDevModeAction.metadata(isEqual: (akActionTitle, akActionDestructive)) else { return }
            presumedDevModeAction.perform()
        }
    }
    
    private static func destroyConversationDatabase() {
        let previousLanguage = RuntimeStorage.languageCode!
        setLanguageCode("en")
        AKConfirmationAlert(title: "Destroy Database",
                            message: "This will delete all conversations for all users in the \(GeneralSerializer.environment.description.uppercased()) environment.\n\nThis operation cannot be undone.",
                            confirmationStyle: .destructivePreferred).present { confirmed in
            AKCore.shared.unlockLanguageCode(andSetTo: previousLanguage)
            guard confirmed == 1 else { return }
            setLanguageCode("en")
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
    
    private static func eraseDocumentsDirectory() {
        let previousLanguage = RuntimeStorage.languageCode!
        setLanguageCode("en")
        AKConfirmationAlert(title: "Erase Documents Directory",
                            message: "This will remove all files in the userland Documents directory. An app restart is required.",
                            confirmationStyle: .destructivePreferred).present { confirmed in
            defer { AKCore.shared.unlockLanguageCode(andSetTo: previousLanguage) }
            
            guard confirmed == 1 else { return }
            guard let exception = Core.eraseDocumentsDirectory() else {
                AKAlert(message: "The Documents directory has been erased. You must now restart the app.",
                        actions: [AKAction(title: "Exit", style: .destructivePreferred)],
                        showsCancelButton: false).present { _ in
                    fatalError()
                }
                return
            }
            
            setLanguageCode("en")
            AKErrorAlert(error: exception.asAkError()).present { _ in
                AKCore.shared.unlockLanguageCode(andSetTo: previousLanguage)
            }
        }
    }
    
    private static func resetPushTokens() {
        let previousLanguage = RuntimeStorage.languageCode!
        setLanguageCode("en")
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
    
    //==================================================//
    
    /* MARK: - Helper Methods */
    
    private static func setLanguageCode(_ code: String) {
        guard AKCore.shared.languageCodeIsLocked else {
            AKCore.shared.lockLanguageCode(to: code)
            return
        }
        
        AKCore.shared.unlockLanguageCode(andSetTo: code)
    }
}
