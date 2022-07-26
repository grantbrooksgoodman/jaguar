//
//  BuildInfoController.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import UIKit

class BuildInfoController: UIViewController {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    //Overriden Variables
    override var prefersStatusBarHidden:            Bool                 { return false }
    override var preferredStatusBarStyle:           UIStatusBarStyle     { return statusBarStyle }
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { return .slide }
    
    //UIWindows
    private let window = BuildInfoWindow()
    var keyWindow: UIWindow?
    
    //Other Declarations
    let screenBounds = UIScreen.main.bounds
    private(set) var sendFeedbackButton: UIButton!
    var customYOffset: CGFloat? {
        didSet {
            loadView()
        }
    }
    var dismissTimer: Timer?
    var wasHidden = true
    
    //==================================================//
    
    /* MARK: - Initializer Functions */
    
    init() {
        super.init(nibName: nil, bundle: nil)
        
        window.windowLevel = UIWindow.Level(rawValue: CGFloat.greatestFiniteMagnitude)
        window.isHidden = false
        window.rootViewController = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(note:)), name: UIResponder.keyboardDidShowNotification, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    //==================================================//
    
    /* MARK: - Overridden Functions */
    
    override func loadView() {
        let windowView = UIView()
        
        let sendFeedbackButton = getSendFeedbackButton()
        let buildInfoLabel = getBuildInfoLabel(xBaseline: sendFeedbackButton.frame.maxX)
        
        windowView.addSubview(sendFeedbackButton)
        windowView.addSubview(buildInfoLabel)
        
        self.view = windowView
        
        self.sendFeedbackButton = sendFeedbackButton
        window.sendFeedbackButton = sendFeedbackButton
        
        sendFeedbackButton.addTarget(self, action: #selector(self.sendFeedbackButtonAction), for: .touchUpInside)
        window.sendFeedbackButton?.addTarget(self, action: #selector(self.sendFeedbackButtonAction), for: .touchUpInside)
    }
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
    @objc func keyboardDidShow(note: NSNotification) {
        window.windowLevel = UIWindow.Level(rawValue: 0)
        window.windowLevel = UIWindow.Level(rawValue: CGFloat.greatestFiniteMagnitude)
    }
    
    func presentExpiryAlert() {
        window.addBlur(withActivityIndicator: false,
                       withStyle: .light,
                       withTag: aTagFor("BLUR"),
                       alpha: 1)
        
        keyWindow = UIApplication.shared.windows.filter{$0.isKeyWindow}.first
        keyWindow?.isUserInteractionEnabled = false
        
        window.presentExpiryAlert()
    }
    
    #warning("This is an unsafe workaround.")
    @objc func reenableButton() {
        sendFeedbackButton.isEnabled = true
        
        dismissTimer?.invalidate()
        dismissTimer = nil
    }
    
    @objc func sendFeedbackButtonAction() {
        if isPresentingMailComposeViewController {
            AKErrorAlert(message: "It appears that a report is already being filed.\n\nPlease complete the first report before beginning another.",
                         error: AKError(metadata: [#file, #function, #line], isReportable: false)).present()
        } else {
            sendFeedbackButton.isEnabled = false
            
            dismissTimer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(reenableButton), userInfo: nil, repeats: false)
            
            let sendFeedbackAction = AKAction(title: "Send Feedback", style: .default)
            let reportBugAction = AKAction(title: "Report a Bug", style: .default)
            
            AKAlert(title: "File Report",
                    message: "Choose the option which best describes your intention.",
                    actions: [sendFeedbackAction, reportBugAction],
                    networkDependent: true).present { (actionID) in
                        guard actionID != -1 else {
                            return
                        }
                        
                        if actionID == sendFeedbackAction.identifier {
                            AKCore.shared.fileReport(type: .feedback,
                                                     body: "Appended below are various data points useful in analysing any potential problems within the application. Please do not edit the information contained in the lines below, with the exception of the last field, in which any general feedback is appreciated.",
                                                     prompt: "General Feedback",
                                                     extraInfo: nil,
                                                     metadata: [currentFile, #function, #line])
                        } else if actionID == reportBugAction.identifier {
                            AKCore.shared.fileReport(type: .bug,
                                                     body: "In the appropriate section, please describe the error encountered and the steps to reproduce it.",
                                                     prompt: "Description/Steps to Reproduce",
                                                     extraInfo: nil,
                                                     metadata: [currentFile, #function, #line])
                        }
                    }
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func getBuildInfoLabel(xBaseline: CGFloat) -> UILabel {
        let buildInfoLabel = UILabel()
        
        let titleToSet = "\(codeName) \(informationDictionary["bundleVersion"]!) (\(informationDictionary["buildNumberAsString"]!)\(buildTypeAsString(short: true)))"
        
        buildInfoLabel.backgroundColor = .black
        buildInfoLabel.font = UIFont(name: "SFUIText-Bold", size: 13)
        buildInfoLabel.text = titleToSet
        buildInfoLabel.textColor = .white
        
        buildInfoLabel.font = buildInfoLabel.font.withSize(buildInfoLabel.fontSizeThatFits(buildInfoLabel.text))
        
        let buildInfoWidth = buildInfoLabel.sizeThatFits(buildInfoLabel.intrinsicContentSize).width
        
        let buildInfoXOrigin = xBaseline - (buildInfoWidth)
        let buildInfoYOrigin = UIScreen.main.bounds.maxY - ((15 + 20) + (customYOffset ?? 0))
        
        buildInfoLabel.frame = CGRect(x: buildInfoXOrigin, y: buildInfoYOrigin, width: buildInfoWidth, height: 15)
        
        return buildInfoLabel
    }
    
    private func getSendFeedbackButton() -> UIButton {
        let sendFeedbackButton = UIButton(type: .system)
        
        let sendFeedbackAttributes: [NSAttributedString.Key: Any] = [.font: UIFont(name: "Arial", size: 12)!,
                                                                     .foregroundColor: UIColor.white,
                                                                     .underlineStyle: NSUnderlineStyle.single.rawValue]
        
        let sendFeedbackAttributedString = NSMutableAttributedString(string: Localizer.preLocalizedString(for: .sendFeedback) ?? "Send Feedback", attributes: sendFeedbackAttributes)
        
        sendFeedbackButton.setAttributedTitle(sendFeedbackAttributedString, for: .normal)
        
        let sendFeedbackHeight = sendFeedbackButton.intrinsicContentSize.height - 5
        let sendFeedbackWidth = sendFeedbackButton.intrinsicContentSize.width
        
        let sendFeedbackXOrigin = screenBounds.width - (sendFeedbackWidth + 25)
        let sendFeedbackYOrigin = screenBounds.maxY - ((sendFeedbackHeight + 35) + (customYOffset ?? 0))
        
        sendFeedbackButton.backgroundColor = .black
        sendFeedbackButton.frame = CGRect(x: sendFeedbackXOrigin, y: sendFeedbackYOrigin, width: sendFeedbackWidth, height: sendFeedbackHeight)
        
        return sendFeedbackButton
    }
}

private class BuildInfoWindow: UIWindow {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    //Public Variables
    public var sendFeedbackButton: UIButton?
    
    //Private Variables
    private var exitTimer: Timer?
    private var expiryAlertController: UIAlertController!
    private var expiryMessage = "The evaluation period for this pre-release build of \(codeName) has ended.\n\nTo continue using this version, enter the six-digit expiration override code associated with it.\n\nUntil updated to a newer build, entry of this code will be required each time the application is launched.\n\nTime remaining for successful entry: 00:30"
    private var remainingSeconds = 30
    
    private var expiryTitle = "End of Evaluation Period"
    private var continueUseString = "Continue Use"
    private var incorrectCodeTitle = "Incorrect Override Code"
    private var incorrectCodeMessage = "The code entered was incorrect.\n\nPlease enter the correct expiration override code or exit the application."
    private var tryAgainString = "Try Again"
    private var exitApplicationString = "Exit Application"
    private var timeExpiredTitle = "Time Expired"
    private var timeExpiredMessage = "The application will now exit."
    
    //==================================================//
    
    /* MARK: - Initializer Functions */
    
    init() {
        super.init(frame: UIScreen.main.bounds)
        
        backgroundColor = nil
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //==================================================//
    
    /* MARK: - Overridden Functions */
    
    fileprivate override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let expiryAlertController = expiryAlertController else {
            guard let sendFeedbackButton = sendFeedbackButton else {
                return false
            }
            
            let buttonPoint = convert(point, to: sendFeedbackButton)
            
            return sendFeedbackButton.point(inside: buttonPoint, with: event)
        }
        
        let buttonPoint = convert(point, to: expiryAlertController.view)
        
        return expiryAlertController.view.point(inside: buttonPoint, with: event)
    }
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
    public func presentExpiryAlert() {
        translateStrings {
            self.expiryAlertController = UIAlertController(title: self.expiryTitle,
                                                           message: self.expiryMessage,
                                                           preferredStyle: .alert)
            
            self.expiryAlertController.addTextField { textField in
                textField.clearButtonMode = .never
                textField.isSecureTextEntry = true
                textField.keyboardAppearance = .light
                textField.keyboardType = .numberPad
                textField.placeholder = "\(informationDictionary["bundleVersion"]!) | \(informationDictionary["buildSku"]!)"
                textField.textAlignment = .center
            }
            
            let continueUseAction = UIAlertAction(title: self.continueUseString,
                                                  style: .default) { _ in
                let returnedString = self.expiryAlertController.textFields![0].text!
                
                if returnedString == self.getExpirationOverrideCode() {
                    self.exitTimer?.invalidate()
                    self.exitTimer = nil
                    
                    if let blurView = self.subview(aTagFor("BLUR")) {
                        UIView.animate(withDuration: 0.2) {
                            blurView.alpha = 0
                        } completion: { _ in
                            blurView.removeFromSuperview()
                            buildInfoController?.keyWindow?.isUserInteractionEnabled = true
                            self.expiryAlertController = nil
                        }
                    }
                } else {
                    let incorrectAlertController = UIAlertController(title: self.incorrectCodeTitle,
                                                                     message: self.incorrectCodeMessage,
                                                                     preferredStyle: .alert)
                    
                    let tryAgainAction = UIAlertAction(title: self.tryAgainString,
                                                       style: .default) { _ in
                        self.presentExpiryAlert()
                    }
                    
                    let exitApplicationAction = UIAlertAction(title: self.exitApplicationString,
                                                              style: .destructive) { _ in
                        fatalError()
                    }
                    
                    incorrectAlertController.addAction(tryAgainAction)
                    incorrectAlertController.addAction(exitApplicationAction)
                    incorrectAlertController.preferredAction = tryAgainAction
                    
                    buildInfoController?.present(incorrectAlertController, animated: true)
                }
            }
            
            continueUseAction.isEnabled = false
            
            self.expiryAlertController.addAction(continueUseAction)
            
            NotificationCenter.default.addObserver(forName: UITextField.textDidChangeNotification, object: self.expiryAlertController.textFields![0], queue: .main) { _ in
                continueUseAction.isEnabled = (self.expiryAlertController.textFields![0].text!.lowercasedTrimmingWhitespace.count == 6)
            }
            
            self.expiryAlertController.addAction(UIAlertAction(title: self.exitApplicationString,
                                                               style: .destructive) { _ in
                fatalError()
            })
            
            self.expiryAlertController.preferredAction = self.expiryAlertController.actions[0]
            
            self.setAttributedExpiryMessage()
            
            buildInfoController?.present(self.expiryAlertController, animated: true)
            
            guard let timer = self.exitTimer else {
                self.exitTimer = Timer.scheduledTimer(timeInterval: 1,
                                                      target: self,
                                                      selector: #selector(self.decrementSecond),
                                                      userInfo: nil,
                                                      repeats: true)
                return
            }
            
            if !timer.isValid {
                self.exitTimer = Timer.scheduledTimer(timeInterval: 1,
                                                      target: self,
                                                      selector: #selector(self.decrementSecond),
                                                      userInfo: nil,
                                                      repeats: true)
            }
        }
    }
    
    private func translateStrings(completion: @escaping() -> Void) {
        let dispatchGroup = DispatchGroup()
        var leftDispatchGroup = false
        
        var inputsToTranslate = [TranslationInput(expiryTitle),
                                 TranslationInput(expiryMessage),
                                 TranslationInput(continueUseString),
                                 TranslationInput(incorrectCodeTitle),
                                 TranslationInput(incorrectCodeMessage),
                                 TranslationInput(tryAgainString),
                                 TranslationInput(exitApplicationString),
                                 TranslationInput(timeExpiredTitle),
                                 TranslationInput(timeExpiredMessage)]
        
        inputsToTranslate = inputsToTranslate.filter({$0.value().lowercasedTrimmingWhitespace != ""})
        
        dispatchGroup.enter()
        TranslatorService.main.getTranslations(for: inputsToTranslate,
                                               languagePair: LanguagePair(from: "en",
                                                                          to: languageCode),
                                               requiresHUD: true,
                                               using: .google) { (returnedTranslations,
                                                                  errorDescriptors) in
            guard let translations = returnedTranslations else {
                Logger.log(errorDescriptors?.keys.joined(separator: "\n") ?? "An unknown error occurred.",
                           metadata: [#file, #function, #line])
                return
            }
            
            self.expiryTitle = translations.first(where: { $0.input.value() == self.expiryTitle })?.output ?? self.expiryTitle
            self.expiryMessage = translations.first(where: { $0.input.value() == self.expiryMessage })?.output ?? self.expiryMessage
            self.continueUseString = translations.first(where: { $0.input.value() == self.continueUseString })?.output ?? self.continueUseString
            self.incorrectCodeTitle = translations.first(where: { $0.input.value() == self.incorrectCodeTitle })?.output ?? self.incorrectCodeTitle
            self.incorrectCodeMessage = translations.first(where: { $0.input.value() == self.incorrectCodeMessage })?.output ?? self.incorrectCodeMessage
            self.tryAgainString = translations.first(where: { $0.input.value() == self.tryAgainString })?.output ?? self.tryAgainString
            self.exitApplicationString = translations.first(where: { $0.input.value() == self.exitApplicationString })?.output ?? self.exitApplicationString
            self.timeExpiredTitle = translations.first(where: { $0.input.value() == self.timeExpiredTitle })?.output ?? self.timeExpiredTitle
            self.timeExpiredMessage = translations.first(where: { $0.input.value() == self.timeExpiredMessage })?.output ?? self.timeExpiredMessage
            
            if !leftDispatchGroup {
                dispatchGroup.leave()
                leftDispatchGroup = true
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion()
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    @objc private func decrementSecond() {
        remainingSeconds -= 1
        
        if remainingSeconds < 0 {
            exitTimer?.invalidate()
            exitTimer = nil
            
            buildInfoController?.dismiss(animated: true, completion: {
                let alertController = UIAlertController(title: self.timeExpiredTitle,
                                                        message: self.timeExpiredMessage,
                                                        preferredStyle: .alert)
                
                buildInfoController?.present(alertController, animated: true)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1500)) {
                    fatalError()
                }
            })
        } else {
            let decrementString = String(format: "%02d", remainingSeconds)
            
            expiryMessage = "\(expiryMessage.components(separatedBy: ":")[0]): 00:\(decrementString)"
            
            setAttributedExpiryMessage()
        }
    }
    
    private func getExpirationOverrideCode() -> String {
        let firstLetter = String(codeName.first!)
        let lastLetter = String(codeName.last!)
        
        let middleIndex = codeName.index(codeName.startIndex,
                                         offsetBy: Int((Double(codeName.count) / 2).rounded(.down)))
        let middleLetter = String(codeName[middleIndex])
        
        var numberStrings: [String] = []
        
        for letter in [firstLetter, middleLetter, lastLetter] {
            numberStrings.append(String(format: "%02d", letter.alphabeticalPosition))
        }
        
        return numberStrings.joined()
    }
    
    private func setAttributedExpiryMessage() {
        let alternateAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.red,
                                                                  .font: UIFont.systemFont(ofSize: 17)]
        
        let messageComponents = expiryMessage.components(separatedBy: ":")
        let attributeRange = messageComponents[1...messageComponents.count - 1].joined(separator: ":")
        
        let attributedMessage = attributedString(expiryMessage,
                                                 mainAttributes: [.font: UIFont.systemFont(ofSize: 13)],
                                                 alternateAttributes: alternateAttributes,
                                                 alternateAttributeRange: [attributeRange])
        
        expiryAlertController.setValue(attributedMessage, forKey: "attributedMessage")
    }
}
