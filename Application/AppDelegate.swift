//
//  AppDelegate.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import CoreTelephony
import MessageUI
import UIKit

/* Third-party Frameworks */
import Firebase
import PKHUD
import Reachability

//==================================================//

/* MARK: - Top-level Variable Declarations */

//Booleans
var darkMode                              = false
var isPresentingMailComposeViewController = false
var prefersConsistentBuildInfo            = false
var streamOpen                            = false
var timebombActive                        = true
var verboseFunctionExposure               = true

//DateFormatters
let masterDateFormatter    = DateFormatter()
let secondaryDateFormatter = DateFormatter()

//Dictionaries
var dismissDictionary:              [String: String]!
var followingUnableDictionary:      [String: String]!
var languageCodeDictionary:         [String: String]!
var noInternetMessageDictionary:    [String: String]!
var noInternetTitleDictionary:      [String: String]!
var notSupportedMessageDictionary:  [String: String]!
var sendFeedbackDictionary:         [String: String]!
var translationArchive = [Translation]() {
    didSet {
        TranslationArchiver.setArchive()
    }
}
var unableMessageDictionary:        [String: String]!
var unableTitleDictionary:          [String: String]!

//Strings
var callingCode: String!
var codeName                  = "Jaguar"
var currentFile               = #file
var dmyFirstCompileDateString = "23042022"
var finalName                 = ""
var languageCode              = ["ca", "es", "fr", "gl", "it", "pt", "ro"].randomElement()! //["af", "ga", "sq", "it", "ar", "ja", "az", "kn", "eu", "ko", "bn", "la", "be", "lv", "bg", "lt", "ca", "mk", "zh-CN", "ms", "zh-TW", "mt", "hr", "no", "cs", "fa", "da", "pl", "nl", "pt", "ro", "eo", "ru", "et", "sr", "tl", "sk", "fi", "sl", "fr", "es", "gl", "sw", "ka", "sv", "de", "ta", "el", "te", "gu", "th", "ht", "tr", "iw", "uk", "hi", "ur", "hu", "vi", "is", "cy", "id", "yi"].randomElement()! //Locale.preferredLanguages[0].components(separatedBy: "-")[0]

//UIViewControllers
var buildInfoController: BuildInfoController?
var frontmostViewController: UIViewController!

//Other Declarations
let telephonyNetworkInfo = CTTelephonyNetworkInfo()

var appStoreReleaseVersion = 0
var buildType: Build.BuildType = .preAlpha
var currentCalendar = Calendar(identifier: .gregorian)
var informationDictionary: [String:String]!
var statusBarStyle: UIStatusBarStyle = .default
var touchTimer: Timer?

//==================================================//

@UIApplicationMain class AppDelegate: UIResponder, MFMailComposeViewControllerDelegate, UIApplicationDelegate, UIGestureRecognizerDelegate {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    //Boolean Declarations
    var currentlyAnimating = false
    var hasResigned        = false
    
    //Other Declarations
    let screenSize = UIScreen.main.bounds
    
    var informationDictionary: [String:String] = [:]
    var window: UIWindow?
    
    //==================================================//
    
    /* MARK: - Required Functions */
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let tapGesture = UITapGestureRecognizer(target: self, action: nil)
        tapGesture.delegate = self
        window?.addGestureRecognizer(tapGesture)
        
        currentCalendar.timeZone = TimeZone(abbreviation: "GMT")!
        
        masterDateFormatter.dateFormat = "yyyy-MM-dd"
        masterDateFormatter.locale = Locale(identifier: "en_GB")
        
        secondaryDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        secondaryDateFormatter.locale = Locale(identifier: "en_GB")
        
        if let essentialLocalisations = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "EssentialLocalizations", ofType: "plist") ?? "") as? [String: [String: String]] {
            
            dismissDictionary = essentialLocalisations["dismiss"]!
            followingUnableDictionary = essentialLocalisations["following_unable"]!
            languageCodeDictionary = essentialLocalisations["language_codes"]!
            noInternetMessageDictionary = essentialLocalisations["no_internet_message"]!
            noInternetTitleDictionary = essentialLocalisations["no_internet_title"]!
            notSupportedMessageDictionary = essentialLocalisations["not_supported"]!
            sendFeedbackDictionary = essentialLocalisations["send_feedback"]!
            unableMessageDictionary = essentialLocalisations["unable_message"]!
            unableTitleDictionary = essentialLocalisations["unable_title"]!
            
            if languageCodeDictionary[languageCode] == nil {
                languageCode = "en"
                
                log("Unsupported language code; reverting to English.",
                    metadata: [#file, #function, #line])
            }
        } else {
            log("Essential localizations missing.",
                isFatal: true,
                metadata: [#file, #function, #line])
        }
        
        if let code = getCallingCode() {
            callingCode = "+\(code) "
        } else {
            callingCode = "+"
        }
        
        //Set the array of information.
        Build.shared.setInformationDictionary()
        buildInfoController = BuildInfoController()
        buildInfoController?.view.isHidden = true
        
        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.min)
        
        TranslationArchiver.getArchive { (returnedTranslations,
                                          errorDescriptor) in
            if let deSerialized = returnedTranslations {
                if !deSerialized.contains(where: { $0.languagePair.to == languageCode }) {
                    log("Different language codes, nuking translation archive.",
                        metadata: [#file, #function, #line])
                    
                    UserDefaults.standard.setValue(nil, forKey: "translationArchive")
                } else {
                    translationArchive = deSerialized
                }
            } else if let error = errorDescriptor {
                UserDefaults.standard.setValue(nil, forKey: "translationArchive")
                
                log(error, metadata: [#file, #function, #line])
            }
        }
        
        TranslationSerializer.downloadTranslations()
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        if currentlyAnimating && hasResigned {
            frontmostViewController.performSegue(withIdentifier: "initialSegue", sender: self)
            currentlyAnimating = false
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        hasResigned = true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        
    }
    
    //==================================================//
    
    /* MARK: - Push Notification Functions */
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        
        return false
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        touchTimer?.invalidate()
        touchTimer = nil
        
        UIView.animate(withDuration: 0.2, animations: { buildInfoController?.view.alpha = 0.35 }) { (_) in
            if touchTimer == nil {
                touchTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.touchTimerAction), userInfo: nil, repeats: true)
            }
        }
        
        return false
    }
    
    @objc func touchTimerAction() {
        UIView.animate(withDuration: 0.2, animations: {
            if touchTimer != nil {
                buildInfoController?.view.alpha = 1
                
                touchTimer?.invalidate()
                touchTimer = nil
            }
        })
    }
}

//==================================================//

/* MARK: - Helper Functions */

/**/

/* MARK: Dispatch Queue Functions */

func after(milliseconds: Int, do: @escaping () -> Void = { }) {
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(milliseconds), execute: {
        `do`()
    })
}

func after(seconds: Int, do: @escaping () -> Void = { }) {
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds), execute: {
        `do`()
    })
}

//--------------------------------------------------//

/* MARK: Error Processing Functions */

/**
 Converts an instance of `Error` to a formatted string.
 
 - Parameter for: The `Error` whose information will be extracted.
 
 - Returns: A string with the error's localized description and code.
 */
func errorInfo(_ for: Error) -> String {
    let asNSError = `for` as NSError
    
    return "\(asNSError.localizedDescription) (\(asNSError.code))"
}

/**
 Converts an instance of `NSError` to a formatted string.
 
 - Parameter for: The `NSError` whose information will be extracted.
 
 - Returns: A string with the error's localized description and code.
 */
func errorInfo(_ for: NSError) -> String {
    return "\(`for`.localizedDescription) (\(`for`.code))"
}

//--------------------------------------------------//

/* MARK: Event Reporting Functions */

///Closes a console stream.
func closeStream(onLine: Int? = nil, message: String? = nil) {
    if verboseFunctionExposure {
        streamOpen = false
        
        if let closingMessage = message, let lastLine = onLine {
            print("[\(lastLine)]: \(closingMessage)\n*------------------------STREAM CLOSED------------------------*\n")
        } else {
            print("*------------------------STREAM CLOSED------------------------*\n")
        }
    }
}

func fallbackLog(_ text: String,
                 errorCode: Int? = nil,
                 isFatal: Bool? = nil) {
    if let unwrappedErrorCode = errorCode {
        print("\n--------------------------------------------------\n[IMPROPERLY FORMATTED METADATA]\n\(text) (\(unwrappedErrorCode))\n--------------------------------------------------\n")
    } else {
        print("\n--------------------------------------------------\n[IMPROPERLY FORMATTED METADATA]\n\(text)\n--------------------------------------------------\n")
    }
    
    guard let fatal = isFatal else {
        return
    }
    
    if fatal {
        AKCore.shared.present(.fatalErrorAlert,
                              with: [text, [#file, #function, #line]])
    }
}

/**
 Prints a formatted event report to the console. Also supports displaying a fatal error alert.
 
 - Parameter text: The content of the message to print.
 - Parameter errorCode: An optional error code to include in the report.
 
 - Parameter isFatal: A Boolean representing whether or not to display a fatal error alert along with the event report.
 - Parameter metadata: The metadata array. Must contain the **file name, function name, and line number** in that order.
 */
func log(_ text: String,
         errorCode: Int? = nil,
         isFatal: Bool? = nil,
         verbose: Bool? = nil,
         metadata: [Any]) {
    if let verbose = verbose {
        if verbose && !verboseFunctionExposure {
            return
        }
    }
    
    guard validateMetadata(metadata) else {
        fallbackLog(text, errorCode: errorCode, isFatal: isFatal ?? false)
        return
    }
    
    let unformattedFileName = metadata[0] as! String
    let unformattedFunctionName = metadata[1] as! String
    let lineNumber = metadata[2] as! Int
    
    #warning("Need to flesh this out more. Account for isFatal.")
    guard !streamOpen else {
        logToStream(line: lineNumber, message: text)
        return
    }
    
    let fileName = AKCore.shared.fileName(for: unformattedFileName)
    let functionName = unformattedFunctionName.components(separatedBy: "(")[0]
    
    if let unwrappedErrorCode = errorCode {
        print("\n--------------------------------------------------\n\(fileName): \(functionName)() [\(lineNumber)]\n\(text) (\(unwrappedErrorCode))\n--------------------------------------------------\n")
        
        guard let fatal = isFatal else {
            return
        }
        
        if fatal {
            AKCore.shared.present(.fatalErrorAlert,
                                  with: ["\(text) (\(unwrappedErrorCode))",
                                         [fileName, functionName, lineNumber]])
        }
    } else {
        print("\n--------------------------------------------------\n\(fileName): \(functionName)() [\(lineNumber)]\n\(text)\n--------------------------------------------------\n")
        
        guard let fatal = isFatal else {
            return
        }
        
        if fatal {
            AKCore.shared.present(.fatalErrorAlert,
                                  with: [text, [fileName, functionName, lineNumber]])
        }
    }
}

//func logToStreamWithNewContext(_ text: String,
//                               errorCode: Int? = nil,
//                               metadata: [Any]) {
//    guard validateMetadata(metadata) else {
//        fallbackLog(text, errorCode: errorCode, isFatal: false)
//        return
//    }
//
//    let unformattedFileName = metadata[0] as! String
//    let unformattedFunctionName = metadata[1] as! String
//    let lineNumber = metadata[2] as! Int
//
//    let fileName = AKCore.shared.fileName(for: unformattedFileName)
//    let functionName = unformattedFunctionName.components(separatedBy: "(")[0]
//
//    if let unwrappedErrorCode = errorCode {
//        print("\n\(fileName): \(functionName)()\n[\(lineNumber)]: \(text) (\(unwrappedErrorCode))")
//    } else {
//        print("\n\(fileName): \(functionName)()\n[\(lineNumber)]: \(text)")
//    }
//}

///Logs to the console stream.
func logToStream(line: Int, message: String) {
    if verboseFunctionExposure {
        print("[\(line)]: \(message)")
    }
}

///Opens a console stream.
func openStream(metadata: [Any], message: String?) {
    if verboseFunctionExposure {
        guard validateMetadata(metadata) else {
            log("Improperly formatted metadata.",
                metadata: [#file, #function, #line])
            return
        }
        
        let unformattedFileName = metadata[0] as! String
        let unformattedFunctionName = metadata[1] as! String
        let lineNumber = metadata[2] as! Int
        
        let fileName = AKCore.shared.fileName(for: unformattedFileName)
        let functionName = unformattedFunctionName.components(separatedBy: "(")[0]
        
        streamOpen = true
        
        if let firstEntry = message {
            print("\n*------------------------STREAM OPENED------------------------*\n\(fileName): \(functionName)()\n[\(lineNumber)]: \(firstEntry)")
        } else {
            print("\n*------------------------STREAM OPENED------------------------*\n\(fileName): \(functionName)()")
        }
    }
}

func validateMetadata(_ metadata: [Any]) -> Bool {
    guard metadata.count == 3 else {
        return false
    }
    
    guard metadata[0] is String else {
        return false
    }
    
    guard metadata[1] is String else {
        return false
    }
    
    guard metadata[2] is Int else {
        return false
    }
    
    return true
}

//--------------------------------------------------//

/* MARK: First Responder Functions */

///Finds and resigns the first responder.
func findAndResignFirstResponder() {
    DispatchQueue.main.async {
        if let unwrappedFirstResponder = findFirstResponder(inView: frontmostViewController.view) {
            unwrappedFirstResponder.resignFirstResponder()
        }
    }
}

///Finds the first responder in a given view.
func findFirstResponder(inView view: UIView) -> UIView? {
    for individualSubview in view.subviews {
        if individualSubview.isFirstResponder {
            return individualSubview
        }
        
        if let recursiveSubview = findFirstResponder(inView: individualSubview) {
            return recursiveSubview
        }
    }
    
    return nil
}

//--------------------------------------------------//

/* MARK: HUD Functions */

///Hides the HUD.
func hideHUD() {
    DispatchQueue.main.async {
        if PKHUD.sharedHUD.isVisible {
            PKHUD.sharedHUD.hide(true)
        }
    }
}

func hideHUD(delay: Double?) {
    if let delay = delay {
        let millisecondDelay = Int(delay * 1000)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(millisecondDelay)) {
            if PKHUD.sharedHUD.isVisible {
                PKHUD.sharedHUD.hide(true)
            }
        }
    } else {
        DispatchQueue.main.async {
            if PKHUD.sharedHUD.isVisible {
                PKHUD.sharedHUD.hide(true)
            }
        }
    }
}

func hideHUD(delay: Double?, completion: @escaping() -> Void) {
    if let delay = delay {
        let millisecondDelay = Int(delay * 1000)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(millisecondDelay)) {
            if PKHUD.sharedHUD.isVisible {
                PKHUD.sharedHUD.hide(animated: true) { (_) in
                    completion()
                }
            }
        }
    } else {
        DispatchQueue.main.async {
            if PKHUD.sharedHUD.isVisible {
                PKHUD.sharedHUD.hide(true) { (_) in
                    completion()
                }
            }
        }
    }
}

///Shows the progress HUD.
func showProgressHUD() {
    DispatchQueue.main.async {
        if !PKHUD.sharedHUD.isVisible {
            PKHUD.sharedHUD.contentView = PKHUDProgressView()
            PKHUD.sharedHUD.show(onView: frontmostViewController.view)
        }
    }
}

func showProgressHUD(text: String?, delay: Double?) {
    if let delay = delay {
        let millisecondDelay = Int(delay * 1000)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(millisecondDelay)) {
            if !PKHUD.sharedHUD.isVisible {
                PKHUD.sharedHUD.contentView = PKHUDProgressView(title: nil, subtitle: text)
                PKHUD.sharedHUD.show(onView: frontmostViewController.view)
            }
        }
    } else {
        DispatchQueue.main.async {
            if !PKHUD.sharedHUD.isVisible {
                PKHUD.sharedHUD.contentView = PKHUDProgressView(title: nil, subtitle: text)
                PKHUD.sharedHUD.show(onView: frontmostViewController.view)
            }
        }
    }
}

//--------------------------------------------------//

/* MARK: - Miscellaneous Functions */

///Retrieves the appropriately random tag integer for a given title.
func aTagFor(_ theViewNamed: String) -> Int {
    var finalValue: Float = 1.0
    
    for individualCharacter in String(theViewNamed.unicodeScalars.filter(CharacterSet.letters.contains)).characterArray {
        finalValue += (finalValue / Float(individualCharacter.alphabeticalPosition))
    }
    
    return Int(String(finalValue).replacingOccurrences(of: ".", with: "")) ?? Int().random(min: 5, max: 10)
}

func attributedString(_ with: String,
                      mainAttributes: [NSAttributedString.Key: Any],
                      alternateAttributes: [NSAttributedString.Key: Any],
                      alternateAttributeRange: [String]) -> NSAttributedString {
    let attributedString = NSMutableAttributedString(string: with, attributes: mainAttributes)
    
    for string in alternateAttributeRange {
        let currentRange = (with as NSString).range(of: (string as NSString) as String)
        
        attributedString.addAttributes(alternateAttributes, range: currentRange)
    }
    
    return attributedString
}

func buildTypeAsString(short: Bool) -> String {
    switch buildType {
    case .preAlpha:
        return short ? "p" : "pre-alpha"
    case .alpha:
        return short ? "a" : "alpha"
    case .beta:
        return short ? "b" : "beta"
    case .releaseCandidate:
        return short ? "c" : "release candidate"
    default:
        return short ? "g" : "general"
    }
}

func getCallingCode() -> String? {
    guard let callingCodes = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "CallingCodes", ofType: "plist") ?? "") as? [String: String] else {
        return nil
    }
    
    guard let carrier = telephonyNetworkInfo.serviceSubscriberCellularProviders?.first?.value,
          let countryCode = carrier.isoCountryCode else {
        guard let countryCode = (Locale.current as NSLocale).object(forKey: .countryCode) as? String,
              let callingCode = callingCodes[countryCode.uppercased()] else {
            return nil
        }
        
        return callingCode
    }
    
    return callingCodes[countryCode.uppercased()]
}

///Presents a mail composition view.
func composeMessage(_ message: String,
                    recipients: [String],
                    subject: String,
                    isHTML: Bool,
                    metadata: [Any]) {
    hideHUD(delay: nil)
    
    if MFMailComposeViewController.canSendMail() {
        let composeController = MFMailComposeViewController()
        composeController.mailComposeDelegate = frontmostViewController as! MFMailComposeViewControllerDelegate?
        composeController.setToRecipients(recipients)
        composeController.setMessageBody(message, isHTML: isHTML)
        composeController.setSubject(subject)
        
        if let controller = buildInfoController {
            controller.wasHidden = controller.view.isHidden
            controller.view.isHidden = true
        }
        
        politelyPresent(viewController: composeController)
    } else {
        let error = AKError(nil, metadata: metadata, isReportable: false)
        AKErrorAlert(message: "It appears that your device is not able to send e-mail.\n\nPlease verify that your e-mail client is set up and try again.",
                     error: error,
                     networkDependent: true).present()
    }
}

///Returns a boolean describing whether or not the device has an active Internet connection.
func hasConnectivity() -> Bool {
    let connectionReachability = try! Reachability()
    let networkStatus = connectionReachability.connection.description
    
    return (networkStatus != "No Connection")
}

///Presents a given view controller, but waits for others to be dismissed before doing so.
func politelyPresent(viewController: UIViewController) {
    hideHUD(delay: nil)
    
    if viewController as? MFMailComposeViewController != nil {
        isPresentingMailComposeViewController = true
    }
    
    let keyWindow = UIApplication.shared.windows.filter{$0.isKeyWindow}.first
    
    if var topController = keyWindow?.rootViewController {
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        
        if topController.presentedViewController == nil && !topController.isKind(of: UIAlertController.self) {
            #warning("Something changed in iOS 14 that broke the above code.")
            topController = frontmostViewController
            
            if !Thread.isMainThread {
                DispatchQueue.main.sync {
                    topController.present(viewController, animated: true)
                }
            } else {
                topController.present(viewController, animated: true)
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
                politelyPresent(viewController: viewController)
            })
        }
    }
}

///Rounds the corners on any desired view.
///Numbers 0 through 4 correspond to all, left, right, top, and bottom, respectively.
func roundCorners(forViews: [UIView], withCornerType: Int!) {
    for individualView in forViews {
        var cornersToRound: UIRectCorner!
        
        if withCornerType == 0 {
            //All corners.
            cornersToRound = UIRectCorner.allCorners
        } else if withCornerType == 1 {
            //Left corners.
            cornersToRound = UIRectCorner.topLeft.union(UIRectCorner.bottomLeft)
        } else if withCornerType == 2 {
            //Right corners.
            cornersToRound = UIRectCorner.topRight.union(UIRectCorner.bottomRight)
        } else if withCornerType == 3 {
            //Top corners.
            cornersToRound = UIRectCorner.topLeft.union(UIRectCorner.topRight)
        } else if withCornerType == 4 {
            //Bottom corners.
            cornersToRound = UIRectCorner.bottomLeft.union(UIRectCorner.bottomRight)
        }
        
        let maskPathForView: UIBezierPath = UIBezierPath(roundedRect: individualView.bounds,
                                                         byRoundingCorners: cornersToRound,
                                                         cornerRadii: CGSize(width: 10, height: 10))
        
        let maskLayerForView: CAShapeLayer = CAShapeLayer()
        
        maskLayerForView.frame = individualView.bounds
        maskLayerForView.path = maskPathForView.cgPath
        
        individualView.layer.mask = maskLayerForView
        individualView.layer.masksToBounds = false
        individualView.clipsToBounds = true
    }
}
