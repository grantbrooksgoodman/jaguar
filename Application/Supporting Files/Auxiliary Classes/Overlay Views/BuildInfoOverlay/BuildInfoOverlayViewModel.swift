//
//  BuildInfoOverlayViewModel.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

/* Third-party Frameworks */
import AlertKit
import Translator

public class BuildInfoOverlayViewModel: ObservableObject {
    
    //==================================================//
    
    /* MARK: - Build Information Alert */
    
    public func presentBuildInformationAlert() {
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
    
    //==================================================//
    
    /* MARK: - Disclaimer Alert */
    
    public func presentDisclaimerAlert() {
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
                                                    message: translations.first(where: { $0.input.value() == messageToDisplay })?.output.removingOccurrences(of: ["*"]) ?? messageToDisplay.removingOccurrences(of: ["*"]),
                                                    preferredStyle: .alert)
            
            
            let viewBuildInformationAction = UIAlertAction(title: translations.first(where: { $0.input.value() == viewBuildInformationString })?.output ?? viewBuildInformationString,
                                                           style: .default) { _ in
                self.presentBuildInformationAlert()
            }
            
            let developerModeAction = UIAlertAction(title: translations.first(where: { $0.input.value() == developerModeString })?.output ?? developerModeString,
                                                    style: enableOrDisable == "Enable" ? .default : .destructive) { _ in
                DevModeService.promptToToggle()
            }
            
            alertController.addAction(viewBuildInformationAction)
            alertController.addAction(developerModeAction)
            alertController.addAction(UIAlertAction(title: LocalizedString.dismiss,
                                                    style: .cancel,
                                                    handler: nil))
            
            guard Build.timebombActive else {
                alertController.message = translations.first(where: { $0.input.value() == messageToDisplay })?.output.removingOccurrences(of: ["*"]) ?? messageToDisplay.removingOccurrences(of: ["*"])
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
            
            let message = translations.first(where: { $0.input.value() == messageToDisplay })?.output.removingOccurrences(of: ["*"]) ?? messageToDisplay.removingOccurrences(of: ["*"])
            let attributed = message.attributed(mainAttributes: mainAttributes,
                                                alternateAttributes: alternateAttributes,
                                                alternateAttributeRange: [dateComponent])
            alertController.setValue(attributed, forKey: "attributedMessage")
            
            Core.ui.politelyPresent(viewController: alertController)
        }
    }
    
    //==================================================//
    
    /* MARK: - Send Feedback Action Sheet */
    
    public func presentSendFeedbackActionSheet() {
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
}
