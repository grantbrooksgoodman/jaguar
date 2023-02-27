//
//  BuildInfoOverlayView.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import AlertKit
import Translator

import Firebase

public struct BuildInfoOverlayView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @State public var yOffset: CGFloat = 0
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        VStack {
            Button(action: {
                presentSendFeedbackActionSheet()
            }, label: {
                Text(LocalizedString.sendFeedback)
                    .font(Font.custom("Arial",
                                      size: 12))
                    .foregroundColor(.white)
                    .underline()
            })
            .padding(.horizontal, 1)
            .frame(height: 20)
            .background(Color.black)
            .frame(maxWidth: .infinity,
                   alignment: .trailing)
            .offset(x: -10,
                    y: 8)
            
            Button(action: {
                presentDisclaimerAlert()
            }, label: {
                Text("\(Build.codeName) \(Build.bundleVersion) (\(String(Build.buildNumber))\(Build.stage.description(short: true)))")
                    .font(Font.custom("SFUIText-Bold",
                                      size: 13))
                    .foregroundColor(.white)
            })
            .padding(.all, 1)
            .frame(height: 15)
            .background(Color.black)
            .frame(maxWidth: .infinity,
                   alignment: .trailing)
            .offset(x: -10)
        }
        .offset(x: -10,
                y: yOffset)
        .onShake {
            guard Build.developerModeEnabled else { return }
            presentDeveloperModeActionSheet()
        }
    }
    
    //==================================================//
    
    /* MARK: - User Prompting */
    
    private func presentBuildInformationAlert() {
        let message = "Build Number\n\(String(Build.buildNumber))\n\nBuild Stage\n\(Build.stage.description(short: false).capitalized(with: nil))\n\nBundle Version\n\(Build.bundleVersion)\n\nProject ID\n\(Build.projectID)\n\nSKU\n\(Build.buildSKU)"
        
        let alertController = UIAlertController(title: "",
                                                message: "",
                                                preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: LocalizedString.dismiss,
                                                style: .cancel,
                                                handler: nil))
        
        let mainAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 13)]
        let alternateAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 14)]
        
        let attributed = message.attributed(mainAttributes: mainAttributes,
                                            alternateAttributes: alternateAttributes,
                                            alternateAttributeRange: ["Build Number",
                                                                      "Build Stage",
                                                                      "Bundle Version",
                                                                      "Project ID",
                                                                      "SKU"])
        
        alertController.setValue(attributed, forKey: "attributedMessage")
        
        Core.ui.politelyPresent(viewController: alertController)
    }
    
    private func presentDestroyDatabaseAlert() {
        AKConfirmationAlert(title: "Destroy Database",
                            message: "This will delete all conversations for all users in the \(GeneralSerializer.environment.description.uppercased()) environment.\n\nThis operation cannot be undone.",
                            confirmationStyle: .destructivePreferred).present { didConfirm in
            if didConfirm == 1 {
                AKConfirmationAlert(title: "Are you sure?",
                                    message: "ALL CONVERSATIONS FOR ALL USERS WILL BE DELETED!",
                                    cancelConfirmTitles: (cancel: nil, confirm: "Yes, I'm sure"),
                                    confirmationStyle: .destructivePreferred).present { confirmed in
                    if confirmed == 1 {
                        ConversationTestingSerializer.deleteAllConversations { exception in
                            guard exception == nil else {
                                Logger.log(exception!,
                                           with: .errorAlert)
                                return
                            }
                            
                            RuntimeStorage.conversationsPageViewModel?.load(silent: false)
                        }
                    }
                }
            }
        }
    }
    
    // Make this easier to add to for template.
    private func presentDeveloperModeActionSheet() {
        guard let topViewController = UIApplication.topViewController(),
              !topViewController.isKind(of: UIAlertController.self) else { return }
        
        let developerModeActions = [AKAction(title: "Clear Caches", style: .default),
                                    AKAction(title: "Reset UserDefaults", style: .default),
                                    AKAction(title: "Switch Environment", style: .default),
                                    AKAction(title: "Destroy Conversation Database", style: .destructive),
                                    AKAction(title: "Disable Developer Mode", style: .destructive)]
        
        let actionSheet = AKActionSheet(message: "Developer Mode Options",
                                        actions: developerModeActions,
                                        shouldTranslate: [.none])
        actionSheet.present { actionID in
            switch actionID {
            case developerModeActions[0].identifier:
                ContactArchiver.clearArchive()
                ContactService.clearCache()
                ConversationArchiver.clearArchive()
                RecognitionService.clearCache()
                RegionDetailServer.clearCache()
                TranslationArchiver.clearArchive()
                Core.hud.showSuccess(text: "Cleared Caches")
            case developerModeActions[1].identifier:
                UserDefaults.reset()
                UserDefaults.standard.set(true, forKey: "developerModeEnabled")
                Core.hud.showSuccess(text: "Reset UserDefaults")
            case developerModeActions[2].identifier:
                presentSwitchEnvironmentActionSheet()
            case developerModeActions[3].identifier:
                presentDestroyDatabaseAlert()
            case developerModeActions[4].identifier:
                Build.set(.developerModeEnabled, to: false)
                UserDefaults.standard.set(false, forKey: "developerModeEnabled")
                Core.hud.showSuccess(text: "Developer Mode Disabled")
            default:
                break
            }
        }
    }
    
    private func presentDisclaimerAlert() {
        let typeString = Build.stage.description(short: false)
        let expiryString = Build.timebombActive ? "\n\n\(Build.expiryInfoString)" : ""
        
        var messageToDisplay = "This is a\(typeString == "alpha" ? "n" : "") \(typeString) version of *project code name \(Build.codeName)*.\(expiryString)"
        
        if Build.appStoreReleaseVersion > 0 {
            messageToDisplay = "This is a pre-release update to \(Build.finalName).\(Build.expiryInfoString)"
        }
        
        messageToDisplay += "\n\nAll features presented here are subject to change, and any new or previously undisclosed information presented within this software is to remain strictly confidential.\n\nRedistribution of this software by unauthorized parties in any way, shape, or form is strictly prohibited.\n\nBy continuing your use of this software, you acknowledge your agreement to the above terms.\n\nAll content herein, unless otherwise stated, is copyright © \(Calendar.current.dateComponents([.year], from: Date()).year!) NEOTechnica Corporation. All rights reserved."
        
        let projectTitle = "Project \(Build.codeName)"
        let viewBuildInformationString = "View Build Information"
        
        let enableOrDisable = Build.developerModeEnabled ? "Disable" : "Enable"
        let developerModeString = "\(enableOrDisable) Developer Mode"
        
        TranslatorService.shared.getTranslations(for: [TranslationInput(messageToDisplay),
                                                       TranslationInput(projectTitle),
                                                       TranslationInput(viewBuildInformationString),
                                                       TranslationInput(developerModeString)],
                                                 languagePair: LanguagePair(from: "en",
                                                                            to: RuntimeStorage.languageCode!),
                                                 requiresHUD: false,
                                                 using: .google) { (returnedTranslations,
                                                                    errorDescriptors) in
            guard let translations = returnedTranslations else {
                Logger.log(errorDescriptors?.keys.joined(separator: "\n") ?? "An unknown error occurred.",
                           metadata: [#file, #function, #line])
                return
            }
            
            let alertController = UIAlertController(title: translations.first(where: { $0.input.value() == projectTitle })?.output ?? projectTitle,
                                                    message: translations.first(where: { $0.input.value() == messageToDisplay })?.output ?? messageToDisplay,
                                                    preferredStyle: .alert)
            
            
            let viewBuildInformationAction = UIAlertAction(title: translations.first(where: { $0.input.value() == viewBuildInformationString })?.output ?? viewBuildInformationString,
                                                           style: .default) { _ in
                self.presentBuildInformationAlert()
            }
            
            let developerModeAction = UIAlertAction(title: translations.first(where: { $0.input.value() == developerModeString })?.output ?? developerModeString,
                                                    style: enableOrDisable == "Enable" ? .default : .destructive) { _ in
                self.presentToggleDeveloperModeActionSheet()
            }
            
            alertController.addAction(viewBuildInformationAction)
            alertController.addAction(developerModeAction)
            alertController.addAction(UIAlertAction(title: LocalizedString.dismiss,
                                                    style: .cancel,
                                                    handler: nil))
            
            guard Build.timebombActive else {
                alertController.message = translations.first(where: { $0.input.value() == messageToDisplay })?.output ?? messageToDisplay
                Core.ui.politelyPresent(viewController: alertController)
                
                return
            }
            
            let mainAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 13)]
            let alternateAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.red]
            
            var dateComponent: String!
            let preExpiryComponents = Build.expiryInfoString.components(separatedBy: "expire on")
            let postExpiryComponents = Build.expiryInfoString.components(separatedBy: "ended on")
            
            if preExpiryComponents.count > 1 {
                dateComponent = preExpiryComponents[1].components(separatedBy: ".")[0]
            } else if postExpiryComponents.count > 1 {
                dateComponent = postExpiryComponents[1].components(separatedBy: ".")[0]
            }
            
            let message = translations.first(where: { $0.input.value() == messageToDisplay })?.output ?? messageToDisplay
            let attributed = message.attributed(mainAttributes: mainAttributes,
                                                alternateAttributes: alternateAttributes,
                                                alternateAttributeRange: [dateComponent])
            alertController.setValue(attributed, forKey: "attributedMessage")
            
            Core.ui.politelyPresent(viewController: alertController)
        }
    }
    
    private func presentSendFeedbackActionSheet() {
        let sendFeedbackAction = AKAction(title: "Send Feedback", style: .default)
        let reportBugAction = AKAction(title: "Report a Bug", style: .default)
        
        let actionSheet = AKActionSheet(message: "File a Report",
                                        actions: [sendFeedbackAction, reportBugAction],
                                        networkDependent: true)
        
        actionSheet.present { actionID in
            guard actionID != -1 else { return }
            
            if actionID == sendFeedbackAction.identifier {
                AKCore.shared.reportDelegate().fileReport(forBug: false,
                                                          body: "Any general feedback is appreciated in the appropriate section.",
                                                          prompt: "General Feedback",
                                                          metadata: [RuntimeStorage.currentFile!,
                                                                     #function,
                                                                     #line])
            } else if actionID == reportBugAction.identifier {
                AKCore.shared.reportDelegate().fileReport(forBug: true,
                                                          body: "In the appropriate section, please describe the error encountered and the steps to reproduce it.",
                                                          prompt: "Description/Steps to Reproduce",
                                                          metadata: [RuntimeStorage.currentFile!,
                                                                     #function,
                                                                     #line])
            }
        }
    }
    
    private func presentSwitchEnvironmentActionSheet() {
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
                if actionID == actions[0].identifier {
                    GeneralSerializer.environment = .staging
                } else if actionID == actions[1].identifier {
                    GeneralSerializer.environment = .development
                }
            case .staging:
                if actionID == actions[0].identifier {
                    GeneralSerializer.environment = .production
                } else if actionID == actions[1].identifier {
                    GeneralSerializer.environment = .development
                }
            case .development:
                if actionID == actions[0].identifier {
                    GeneralSerializer.environment = .production
                } else if actionID == actions[1].identifier {
                    GeneralSerializer.environment = .staging
                }
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
    
    private func presentToggleDeveloperModeActionSheet() {
        guard Build.stage != .generalRelease else { return }
        
        guard Build.developerModeEnabled else {
            AKTextFieldAlert(message: "Enter the password to enable Developer Mode.",
                             actions: [AKAction(title: "Done", style: .preferred)],
                             textFieldAttributes: [.secureTextEntry: true,
                                                   .keyboardType: UIKeyboardType.numberPad,
                                                   .textAlignment: NSTextAlignment.center,
                                                   .placeholderText: "••••"],
                             shouldTranslate: [.none]).present { returnedString, actionID in
                guard actionID != -1 else { return }
                if let returnedString,
                   returnedString == ExpiryAlertDelegate().getExpirationOverrideCode() {
                    Build.set(.developerModeEnabled, to: true)
                    UserDefaults.standard.set(true, forKey: "developerModeEnabled")
                    Core.hud.showSuccess(text: "Developer Mode Enabled")
                } else {
                    AKAlert(message: "Wrong password. Please try again.",
                            actions: [AKAction(title: "Try Again", style: .preferred)],
                            shouldTranslate: [.none]).present { actionID in
                        guard actionID != -1 else { return }
                        self.presentToggleDeveloperModeActionSheet()
                    }
                }
            }
            
            return
        }
        
        Build.set(.developerModeEnabled, to: false)
        UserDefaults.standard.set(false, forKey: "developerModeEnabled")
        Core.hud.showSuccess(text: "Developer Mode Disabled")
    }
}
