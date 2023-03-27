//
//  DevModeService.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

/* Third-party Frameworks */
import AlertKit

public struct DevModeService {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private(set) static var actions: [DevModeAction] = []
    
    //==================================================//
    
    /* MARK: - Action Addition */
    
    public static func addAction(_ action: DevModeAction) {
        actions.removeAll(where: { $0.metadata(isEqual: action) })
        actions.append(action)
    }
    
    public static func addActions(_ actions: [DevModeAction]) {
        actions.forEach { action in
            addAction(action)
        }
    }
    
    //==================================================//
    
    /* MARK: - Action Insertion */
    
    public static func insertAction(_ action: DevModeAction,
                                    at index: Int) {
        guard index < actions.count else {
            guard index == actions.count else { return }
            addAction(action)
            return
        }
        
        guard index > -1 else { return }
        actions.removeAll(where: { $0.metadata(isEqual: action) })
        actions.insert(action, at: index)
    }
    
    public static func insertActions(_ actions: [DevModeAction],
                                     at index: Int) {
        actions.forEach { action in
            insertAction(action, at: index)
        }
    }
    
    //==================================================//
    
    /* MARK: - Menu Presentation */
    
    public static func presentActionSheet() {
        guard !actions.isEmpty,
              let topViewController = UIApplication.topViewController(),
              !topViewController.isKind(of: UIAlertController.self) else { return }
        
        var akActions = [AKAction]()
        for action in actions {
            akActions.append(AKAction(title: action.title,
                                      style: action.isDestructive ? .destructive : .default))
        }
        
        let actionSheet = AKActionSheet(message: "Developer Mode Options",
                                        actions: akActions,
                                        shouldTranslate: [.none])
        
        actionSheet.present { actionID in
            guard let index = akActions.firstIndex(where: { $0.identifier == actionID }),
                  index < actions.count else { return }
            
            let selectedAkAction = akActions[index]
            let presumedDevModeAction = actions[index]
            
            let akActionTitle = selectedAkAction.title
            let akActionDestructive = selectedAkAction.style == .destructive
            
            guard presumedDevModeAction.metadata(isEqual: (akActionTitle, akActionDestructive)) else { return }
            presumedDevModeAction.perform()
        }
    }
    
    //==================================================//
    
    /* MARK: - Status Toggling */
    
    public static func promptToToggle() {
        guard Build.stage != .generalRelease else { return }
        
        let previousLanguage = RuntimeStorage.languageCode!
        if AKCore.shared.languageCodeIsLocked {
            AKCore.shared.unlockLanguageCode(andSetTo: "en")
        } else {
            AKCore.shared.lockLanguageCode(to: "en")
        }
        
        guard !Build.developerModeEnabled else {
            AKConfirmationAlert(title: "Disable Developer Mode",
                                message: "Are you sure you'd like to disable Developer Mode?",
                                cancelConfirmTitles: (cancel: nil, confirm: "Disable"),
                                confirmationStyle: .destructivePreferred,
                                shouldTranslate: [.none]).present { confirmed in
                AKCore.shared.unlockLanguageCode(andSetTo: previousLanguage)
                guard confirmed == 1 else { return }
                toggleDeveloperMode(enabled: false)
            }
            
            return
        }
        
        let passwordPrompt = AKTextFieldAlert(title: "Enable Developer Mode",
                                              message: "Enter the Developer Mode password to continue.",
                                              actions: [AKAction(title: "Done", style: .preferred)],
                                              textFieldAttributes: [.keyboardType: UIKeyboardType.numberPad,
                                                                    .placeholderText: "••••••",
                                                                    .secureTextEntry: true,
                                                                    .textAlignment: NSTextAlignment.center],
                                              shouldTranslate: [.none])
        
        passwordPrompt.present { returnedString, actionID in
            AKCore.shared.unlockLanguageCode(andSetTo: previousLanguage)
            
            guard actionID != -1 else { return }
            
            guard let returnedString,
                  returnedString == ExpiryAlertDelegate().getExpirationOverrideCode() else {
                AKCore.shared.lockLanguageCode(to: "en")
                AKAlert(title: "Enable Developer Mode",
                        message: "The password entered was not correct. Please try again.",
                        actions: [AKAction(title: "Try Again", style: .preferred)],
                        shouldTranslate: [.none]).present { actionID in
                    AKCore.shared.unlockLanguageCode(andSetTo: previousLanguage)
                    guard actionID != -1 else { return }
                    self.promptToToggle()
                }
                
                return
            }
            
            toggleDeveloperMode(enabled: true)
        }
    }
    
    //==================================================//
    
    /* MARK: - Helper Methods */
    
    private static func toggleDeveloperMode(enabled: Bool) {
        Build.set(.developerModeEnabled, to: enabled)
        UserDefaults.standard.set(enabled, forKey: "developerModeEnabled")
        StateProvider.shared.developerModeEnabled = enabled
        Core.hud.showSuccess(text: "Developer Mode \(enabled ? "Enabled" : "Disabled")")
    }
}
