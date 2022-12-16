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

public struct BuildInfoOverlayView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @State public var yOffset: CGFloat = 0
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        VStack {
            Button(action: {
                presentSendFeedbackAlert()
            }, label: {
                Text(Localizer
                    .preLocalizedString(for: .sendFeedback) ?? "Send Feedback")
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
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func presentBuildInformationAlert() {
        let message = "Build Number\n\(String(Build.buildNumber))\n\nBuild Stage\n\(Build.stage.description(short: false).capitalized(with: nil))\n\nBundle Version\n\(Build.bundleVersion)\n\nProject ID\n\(Build.projectID)\n\nSKU\n\(Build.buildSKU)"
        
        let alertController = UIAlertController(title: "",
                                                message: "",
                                                preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: Localizer
            .preLocalizedString(for: .dismiss) ?? "Dismiss",
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
    
    private func presentDisclaimerAlert() {
        let typeString = Build.stage.description(short: false)
        let expiryString = Build.timebombActive ? "\n\n\(Build.expiryInfoString)" : ""
        
        var messageToDisplay = "This is a\(typeString == "alpha" ? "n" : "") \(typeString) version of project code name \(Build.codeName).\(expiryString)"
        
        if typeString == "general" {
            messageToDisplay = "This is a pre-release update to \(Build.finalName).\(Build.expiryInfoString)"
        }
        
        messageToDisplay += "\n\nAll features presented here are subject to change, and any new or previously undisclosed information presented within this software is to remain strictly confidential.\n\nRedistribution of this software by unauthorized parties in any way, shape, or form is strictly prohibited.\n\nBy continuing your use of this software, you acknowledge your agreement to the above terms.\n\nAll content herein, unless otherwise stated, is copyright © \(Calendar.current.dateComponents([.year], from: Date()).year!) NEOTechnica Corporation. All rights reserved."
        
        let projectTitle = "Project \(Build.codeName)"
        let viewBuildInformationString = "View Build Information"
        
        TranslatorService.shared.getTranslations(for: [TranslationInput(messageToDisplay),
                                                       TranslationInput(projectTitle),
                                                       TranslationInput(viewBuildInformationString)],
                                                 languagePair: LanguagePair(from: "en",
                                                                            to: RuntimeStorage.languageCode!),
                                                 requiresHUD: false /*true*/,
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
            
            alertController.addAction(viewBuildInformationAction)
            alertController.addAction(UIAlertAction(title: Localizer
                .preLocalizedString(for: .dismiss) ?? "Dismiss",
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
    
    private func presentSendFeedbackAlert() {
        let sendFeedbackAction = AKAction(title: "Send Feedback", style: .default)
        let reportBugAction = AKAction(title: "Report a Bug", style: .default)
        
        let fileReportAlert = AKAlert(title: "File a Report",
                                      message: "Choose the option which best describes your intention.",
                                      actions: [sendFeedbackAction, reportBugAction],
                                      networkDependent: true)
        
        fileReportAlert.present { actionID in
            guard actionID != -1 else {
                return
            }
            
            if actionID == sendFeedbackAction.identifier {
                AKCore.shared.reportProvider().fileReport(forBug: false,
                                                          body: "Any general feedback is appreciated in the appropriate section.",
                                                          prompt: "General Feedback",
                                                          metadata: [RuntimeStorage.currentFile!,
                                                                     #function,
                                                                     #line])
            } else if actionID == reportBugAction.identifier {
                AKCore.shared.reportProvider().fileReport(forBug: true,
                                                          body: "In the appropriate section, please describe the error encountered and the steps to reproduce it.",
                                                          prompt: "Description/Steps to Reproduce",
                                                          metadata: [RuntimeStorage.currentFile!,
                                                                     #function,
                                                                     #line])
            }
        }
    }
}
