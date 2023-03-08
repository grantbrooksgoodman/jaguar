//
//  ReportDelegate.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import CryptoKit
import MessageUI

/* Third-party Frameworks */
import AlertKit
import FirebaseStorage
import Translator

public class ReportDelegate: UIViewController, AKReportDelegate, MFMailComposeViewControllerDelegate {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private var reportedErrors = [String: String]()
    
    //==================================================//
    
    /* MARK: - Protocol Conformance */
    
    public func fileReport(error: AKError) {
        var injectedError = error
        injectedError = inject(params: commonParams(), into: error)
        
        guard let data = getLogFileData(type: .error,
                                        error: injectedError) else {
            Logger.log(Exception("Couldn't get log file data!", metadata: [#file, #function, #line]))
            return
        }
        
        let namePair = namePair(for: injectedError)
        let logFile = LogFile(fileName: namePair.fileName,
                              directoryName: namePair.directoryName,
                              data: data)
        
        if let params = error.extraParams,
           let hashlet = params["Hashlet"] as? String,
           Array(reportedErrors.keys).contains(hashlet) {
            let fakeLogFile = LogFile(fileName: reportedErrors[hashlet]!,
                                      directoryName: logFile.directoryName,
                                      data: logFile.data)
            self.presentSuccessAlert(logFile: fakeLogFile)
            return
        }
        
        upload(logFile,
               description: (injectedError.extraParams?["Descriptor"] as? String) ?? nil) { exception in
            guard exception == nil else {
                Logger.log(exception!)
                return
            }
            
            self.presentSuccessAlert(logFile: logFile)
            
            Logger.log("Uplodaded file!",
                       metadata: [#file, #function, #line])
        }
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
        
        guard let logFileData = getLogFileData(type: forBug ? .bug : .feedback,
                                               metadata: metadata) else {
            Logger.log(Exception("Couldn't get log file data!",
                                 extraParams: ["OriginalMetadata": metadata],
                                 metadata: [#file, #function, #line]),
                       with: .errorAlert)
            return
        }
        
        var dateHash = Core.secondaryDateFormatter.string(from: Date())
        
        let compressedData = try? (Data(dateHash.utf8) as NSData).compressed(using: .lzfse)
        if let data = compressedData {
            dateHash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        } else {
            dateHash = SHA256.hash(data: Data(dateHash.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        }
        
        let hashlet = dateHash.characterArray[0...dateHash.count / 4]
        let logFile = LogFile(fileName: "\(Build.codeName.lowercased())_\(hashlet.joined())",
                              directoryName: "",
                              data: logFileData)
        
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
                                logFile: logFile)
        }
    }
    
    //==================================================//
    
    /* MARK: - File Management */
    
    private func getLogFileData(type: EnvironmentCodeType,
                                error: AKError? = nil,
                                metadata: [Any]? = nil) -> Data? {
        func getJSON(from dictionary: [String: String]) -> Data? {
            do {
                let encoder = JSONEncoder()
                let encodedMetadata = try encoder.encode(dictionary)
                
                return encodedMetadata
            } catch {
                Logger.log(Exception(error, metadata: [#file, #function, #line]))
                return nil
            }
        }
        
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
            if let json = getJSON(from: sections) {
                return json
            }
            
            return nil
        }
        
        var finalDescriptor = error.description ?? ""
        
        if let extraParams = error.extraParams,
           let descriptor = extraParams["Descriptor"] as? String {
            if let hashlet = extraParams["Hashlet"] as? String {
                finalDescriptor = "\(descriptor) (\(hashlet.uppercased()))"
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
            return json
        }
        
        return nil
    }
    
    private func namePair(for error: AKError) -> (fileName: String, directoryName: String) {
        var directoryName = "NIL"
        var fileName = ReferenceGenerator.referenceCode()
        
        if let extraParams = error.extraParams,
           let hashlet = extraParams["Hashlet"] as? String {
            directoryName = hashlet
            fileName = ReferenceGenerator.referenceCode(with: hashlet)
        }
        
        return (fileName: fileName, directoryName: directoryName)
    }
    
    private func putFile(_ logFile: LogFile) -> String {
        let fileManager = FileManager.default
        
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let path = documentDirectory.appending("/\(logFile.fileName!).log")
        
        guard !fileManager.fileExists(atPath: path) else {
            Logger.log(Exception("File already exists.",
                                 extraParams: ["FilePath": path],
                                 metadata: [#file, #function, #line]))
            return path
        }
        
        guard NSData(data: logFile.data).write(toFile: path, atomically: true) else {
            Logger.log(Exception("Couldn't write to path!",
                                 extraParams: ["FilePath": path],
                                 metadata: [#file, #function, #line]))
            return path
        }
        
        return path
    }
    
    //==================================================//
    
    /* MARK: - File Upload */
    
    private func shouldUpload(for hashlet: String,
                              completion: @escaping(_ shouldUpload: Bool?,
                                                    _ exception: Exception?) -> Void) {
        GeneralSerializer.getValues(atPath: "/doNotStore") { returnedValues, returnedException in
            guard let excludedHashlets = returnedValues as? [String] else {
                completion(nil, returnedException ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            completion(!excludedHashlets.contains(hashlet), nil)
        }
    }
    
    private func upload(_ logFile: LogFile,
                        description: String? = nil,
                        completion: @escaping(_ exception: Exception?) -> Void) {
        guard !Array(reportedErrors.keys).contains(logFile.directoryName) else {
            completion(Exception("Already reported this error.", metadata: [#file, #function, #line]))
            return
        }
        
        shouldUpload(for: logFile.directoryName!) { shouldUpload, exception in
            guard let shouldUpload else {
                completion(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            guard shouldUpload else {
                completion(Exception("Error is excluded from log file upload.",
                                     metadata: [#file, #function, #line]))
                return
            }
            
            let filePath = "reports/\(logFile.directoryName!)/\(logFile.fileName!).log"
            
            let storageMetadata = StorageMetadata(dictionary: ["name": filePath])
            storageMetadata.contentType = "application/json"
            if let description {
                storageMetadata.customMetadata = ["description": description]
            }
            
            Storage.storage().reference().putData(logFile.data,
                                                  metadata: storageMetadata) { metadata, error in
                guard error == nil else {
                    completion(Exception(error!, metadata: [#file, #function, #line]))
                    return
                }
                
                self.reportedErrors[logFile.directoryName] = logFile.fileName
                completion(nil)
            }.resume()
        }
    }
    
    //==================================================//
    
    /* MARK: - Mail Composition */
    
    private func composeMessage(_ messageBody: (message: String, isHTML: Bool)? = nil,
                                recipients: [String],
                                subject: String,
                                logFile: LogFile?) {
        guard MFMailComposeViewController.canSendMail() else {
            let exception = Exception("It appears that your device is not able to send e-mail.\n\nPlease verify that your e-mail client is set up and try again.",
                                      isReportable: false,
                                      metadata: [#file, #function, #line])
            
            AKErrorAlert(error: exception.asAkError(),
                         networkDependent: true).present()
            
            return
        }
        
        let composeController = MFMailComposeViewController()
        composeController.mailComposeDelegate = self
        
        composeController.setSubject(subject)
        composeController.setToRecipients(recipients)
        
        if let body = messageBody {
            composeController.setMessageBody(body.message, isHTML: body.isHTML)
        }
        
        if let file = logFile {
            composeController.addAttachmentData(file.data, mimeType: "application/json", fileName: "\(file.fileName!).log")
        }
        
        Core.ui.present(viewController: composeController)
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
    
    /* MARK: - Other Methods */
    
    private func commonParams() -> [String: String] {
        var parameters = [String: String]()
        
        if let currentFile = RuntimeStorage.currentFile,
           !currentFile.components(separatedBy: "/").isEmpty {
            guard let fileName = currentFile.components(separatedBy: "/").last else { return parameters }
            guard let trimmedFileName = fileName.components(separatedBy: ".").first else { return parameters }
            
            let snakeCaseFileName = trimmedFileName.firstLowercase.snakeCase()
            parameters["CurrentFile"] = snakeCaseFileName
        }
        
        if let currentUserID = RuntimeStorage.currentUserID {
            parameters["CurrentUserID"] = currentUserID
        }
        
        if let languageCode = RuntimeStorage.languageCode {
            parameters["LanguageCode"] = languageCode
        }
        
        return parameters
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
    
    private func presentSuccessAlert(logFile: LogFile) {
        var actions = [AKAction(title: "Copy Reference Code", style: .default)]
        if Build.stage != .generalRelease {
            actions.append(AKAction(title: "Preview File", style: .default))
        }
        
        let alert = AKAlert(title: "This error has been reported, thank you.\n\nYour reference code is displayed below:",
                            message: "\n\(logFile.fileName!)",
                            actions: actions,
                            cancelButtonTitle: "Dismiss",
                            shouldTranslate: [.actions(indices: nil), .cancelButtonTitle, .title])
        
        alert.present { actionID in
            if actionID == alert.actions[0].identifier {
                UIPasteboard.general.string = logFile.fileName
            } else if alert.actions.count > 1,
                      actionID == alert.actions[1].identifier {
                QuickViewer.shared.present(with: self.putFile(logFile))
            }
        }
    }
}
