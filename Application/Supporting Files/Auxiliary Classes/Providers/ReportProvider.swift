//
//  ReportProvider.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import MessageUI

/* Third-party Frameworks */
import AlertKit
import Translator

public class ReportProvider: UIViewController, AKReportProvider, MFMailComposeViewControllerDelegate {
    
    //==================================================//
    
    /* MARK: - Protocol Compliance Function */
    
    public func fileReport(type: ReportType,
                           body: String,
                           prompt: String,
                           extraInfo: String?,
                           metadata: [Any]) {
        var translatedBody = body
        var translatedPrompt = prompt
        
        TranslatorService.shared.getTranslations(for: [Translator.TranslationInput(body),
                                                       Translator.TranslationInput(prompt)],
                                                 languagePair: Translator.LanguagePair(from: "en",
                                                                                       to: RuntimeStorage.languageCode!),
                                                 requiresHUD: false /*true*/,
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
            
            let connectionStatus = Build.isOnline ? "online" : "offline"
            
            let bodySection = translatedBody.split(separator: ".").count > 1 ? "<i>\(translatedBody.split(separator: ".")[0]).<p></p>\(translatedBody.split(separator: ".")[1]).</i><p></p>" : "<i>\(translatedBody.split(separator: ".")[0]).</i><p></p>"
            
            let compiledRemainder = "<b>Project ID:</b> \(Build.projectID)<p></p><b>Build SKU:</b> \(Build.buildSKU)<p></p><b>Occurrence Date:</b> \(Core.secondaryDateFormatter!.string(from: Date()))<p></p><b>Internet Connection Status:</b> \(connectionStatus)<p></p>\(extraInfo == nil ? "" : "<b>Extraneous Information:</b> \(extraInfo!)<p></p>")<b>Reference Code:</b> [\(code)]<p></p><b>\(translatedPrompt):</b> "
            
            let subject = "\(Build.stage == .generalRelease ? Build.finalName : Build.codeName) (\(Build.bundleVersion)) \(type == .bug ? "Bug" : (type == .error ? "Error" : "Feedback")) Report"
            
            self.composeMessage(bodySection + compiledRemainder,
                                recipients: ["me@grantbrooks.io"],
                                subject: subject,
                                isHTML: true,
                                metadata: [#file, #function, #line])
        }
    }
    
    //==================================================//
    
    /* MARK: - Mail Composition Functions */
    
    public func composeMessage(_ message: String,
                               recipients: [String],
                               subject: String,
                               isHTML: Bool,
                               metadata: [Any]) {
        if MFMailComposeViewController.canSendMail() {
            let composeController = MFMailComposeViewController()
            composeController.mailComposeDelegate = self
            composeController.setToRecipients(recipients)
            composeController.setMessageBody(message, isHTML: isHTML)
            composeController.setSubject(subject)
            
            Core.ui.politelyPresent(viewController: composeController)
        } else {
            let error = AKError(nil, metadata: metadata, isReportable: false)
            AKErrorAlert(message: "It appears that your device is not able to send e-mail.\n\nPlease verify that your e-mail client is set up and try again.",
                         error: error,
                         networkDependent: true).present()
        }
    }
    
    public func handleMailComposition(controller: MFMailComposeViewController,
                                      result: MFMailComposeResult,
                                      error: Error?) {
        controller.dismiss(animated: true) {
            Core.gcd.after(seconds: 1) {
                if result == .failed {
                    let error = AKError((error != nil ? Logger.errorInfo(error!) : nil),
                                        metadata: [#file, #function, #line],
                                        isReportable: true)
                    
                    AKErrorAlert(message: "The message failed to send. Please try again.",
                                 error: error,
                                 networkDependent: false).present()
                } else if result == .sent {
                    AKAlert(title: "Message Sent",
                            message: "The message was sent successfully.",
                            cancelButtonTitle: "OK",
                            networkDependent: false).present()
                }
            }
        }
    }
    
    public func mailComposeController(_ controller: MFMailComposeViewController,
                                      didFinishWith result: MFMailComposeResult,
                                      error: Error?) {
        handleMailComposition(controller: controller,
                              result: result,
                              error: error)
    }
}
