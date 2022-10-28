//
//  ReportProvider.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import CryptoKit
import MessageUI

/* Third-party Frameworks */
import AlertKit
import Translator

public class ReportProvider: UIViewController, AKReportProvider, MFMailComposeViewControllerDelegate {
    
    //==================================================//
    
    /* MARK: - Protocol Compliance Functions */
    
    public func fileReport(error: AKError) {
        var injectedError = error
        
        if let currentUserID = RuntimeStorage.currentUserID,
           let languageCode = RuntimeStorage.languageCode {
            injectedError = inject(params: ["CurrentUserID": currentUserID,
                                            "LanguageCode": languageCode],
                                   into: error)
        }
        
        let logFileMetadata = getLogFileMetadata(type: .error, error: injectedError)
        let subject = "\(Build.stage == .generalRelease ? Build.finalName : Build.codeName) (\(Build.bundleVersion)) Error Report"
        
        composeMessage(recipients: ["me@grantbrooks.io"],
                       subject: subject,
                       logFileMetadata: logFileMetadata)
    }
    
    public func fileReport(forBug: Bool,
                           body: String,
                           prompt: String,
                           metadata: [Any]) {
        guard AKCore.shared.validateMetadata(metadata) else {
            Logger.log("Improperly formatted metadata.",
                       metadata: [#file, #function, #line])
            return
        }
        
        let logFileMetadata = getLogFileMetadata(type: forBug ? .bug : .feedback, metadata: metadata)
        let subject = "\(Build.stage == .generalRelease ? Build.finalName : Build.codeName) (\(Build.bundleVersion)) \(forBug ? "Bug" : "Feedback") Report"
        
        var translatedBody = body
        var translatedPrompt = prompt
        
        FirebaseTranslator.shared.getTranslations(for: [Translator.TranslationInput(body),
                                                        Translator.TranslationInput(prompt)],
                                                  languagePair: Translator.LanguagePair(from: "en",
                                                                                        to: RuntimeStorage.languageCode!)) { returnedTranslations, exception in
            guard let translations = returnedTranslations else {
                Logger.log(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            translatedBody = translations.first(where: { $0.input.value() == translatedBody })?.output ?? translatedBody
            translatedPrompt = translations.first(where: { $0.input.value() == translatedPrompt })?.output ?? translatedPrompt
            
            let bodySection = translatedBody.split(separator: ".").count > 1 ? "<i>\(translatedBody.split(separator: ".")[0]).<p></p>\(translatedBody.split(separator: ".")[1]).</i><p></p>" : "<i>\(translatedBody.split(separator: ".")[0]).</i><p></p><b>\(translatedPrompt):</b><p></p>"
            
            self.composeMessage((message: bodySection, isHTML: true),
                                recipients: ["me@grantbrooks.io"],
                                subject: subject,
                                logFileMetadata: logFileMetadata)
        }
    }
    
    //==================================================//
    
    /* MARK: - Mail Composition Functions */
    
    private func composeMessage(_ messageBody: (message: String, isHTML: Bool)? = nil,
                                recipients: [String],
                                subject: String,
                                logFileMetadata: (data: Data, fileName: String)?) {
        if MFMailComposeViewController.canSendMail() {
            let composeController = MFMailComposeViewController()
            composeController.mailComposeDelegate = self
            
            composeController.setSubject(subject)
            composeController.setToRecipients(recipients)
            
            if let body = messageBody {
                composeController.setMessageBody(body.message, isHTML: body.isHTML)
            }
            
            if let metadata = logFileMetadata {
                composeController.addAttachmentData(metadata.data, mimeType: "application/json", fileName: metadata.fileName)
            }
            
            Core.ui.politelyPresent(viewController: composeController)
        } else {
            let exception = Exception("It appears that your device is not able to send e-mail.\n\nPlease verify that your e-mail client is set up and try again.",
                                      isReportable: false,
                                      metadata: [#file, #function, #line])
            
            AKErrorAlert(error: exception.asAkError(),
                         networkDependent: true).present()
        }
    }
    
    public func mailComposeController(_ controller: MFMailComposeViewController,
                                      didFinishWith result: MFMailComposeResult,
                                      error: Error?) {
        controller.dismiss(animated: true) {
            Core.gcd.after(seconds: 1) {
                if result == .failed {
                    AKErrorAlert(error: Exception(error!,
                                                  metadata: [#file, #function, #line]).asAkError(),
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
    
    //==================================================//
    
    /* MARK: - Log File Generation */
    
    private func getHashlet(with exceptionHashlet: String? = nil) -> String {
        var dateHash = Core.secondaryDateFormatter.string(from: Date())
        
        let compressedData = try? (Data(dateHash.utf8) as NSData).compressed(using: .lzfse)
        if let data = compressedData {
            dateHash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        } else {
            dateHash = SHA256.hash(data: Data(dateHash.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        }
        
        let hashlet = dateHash.characterArray[0...dateHash.count / 4]
        
        if let prefix = exceptionHashlet {
            return "\(prefix)x\(hashlet.joined())".lowercased()
        }
        
        return hashlet.joined().lowercased()
    }
    
    private func getJSON(from dictionary: [String: String]) -> Data? {
        do {
            let encoder = JSONEncoder()
            let encodedMetadata = try encoder.encode(dictionary)
            
            return encodedMetadata
        } catch {
            Logger.log(Exception(error, metadata: [#file, #function, #line]))
            return nil
        }
    }
    
    private func getLogFileMetadata(type: EnvironmentCodeType,
                                    error: AKError? = nil,
                                    metadata: [Any]? = nil) -> (data: Data, fileName: String)? {
        guard let environmentCode = AKCore.shared.environmentCode(for: type,
                                                                  metadata: error?.metadata ?? metadata!) else {
            Logger.log("Unable to generate environment code.",
                       with: .fatalAlert,
                       metadata: [#file, #function, #line])
            return nil
        }
        
        let connectionStatus = Build.isOnline ? "online" : "offline"
        
        var sections = ["build_sku": Build.buildSKU,
                        "environment_code": "[\(environmentCode)]",
                        "internet_connection_status": connectionStatus,
                        "occurrence_date": Core.secondaryDateFormatter!.string(from: Date()),
                        "project_id": Build.projectID]
        
        guard let error = error else {
            if let json = self.getJSON(from: sections) {
                return (data: json, fileName: "\(Build.codeName.lowercased())_\(self.getHashlet()).log")
            }
            
            return nil
        }
        
        var finalDescriptor = error.description ?? ""
        var exceptionHashlet: String?
        
        if let extraParams = error.extraParams,
           let descriptor = extraParams["Descriptor"] as? String {
            if let hashlet = extraParams["Hashlet"] as? String {
                finalDescriptor = "\(descriptor) (\(hashlet.uppercased()))"
                exceptionHashlet = hashlet
            } else {
                finalDescriptor = descriptor
            }
        }
        
        if finalDescriptor != "" {
            sections["error_descriptor"] = finalDescriptor
        }
        
        if let extraParams = error.extraParams?.filter({ $0.key != "Descriptor" }).filter({ $0.key != "Hashlet" }),
           extraParams.count > 0 {
            // #warning("Don't know if this is really needed; can make it private.")
            sections["extra_parameters"] = extraParams.withCapitalizedKeys.description.replacingOccurrences(of: "\"", with: "'")
        }
        
        if let json = getJSON(from: sections) {
            return (data: json, fileName: "\(Build.codeName.lowercased())_\(getHashlet(with: exceptionHashlet)).log")
        }
        
        return nil
    }
    
    private func inject(params: [String: Any], into: AKError) -> AKError {
        var mutable = into
        
        guard var existingParams = mutable.extraParams else {
            mutable.extraParams = params
            return mutable
        }
        
        params.forEach { parameter in
            existingParams[parameter.key] = parameter.value
        }
        
        mutable.extraParams = existingParams
        return mutable
    }
}
