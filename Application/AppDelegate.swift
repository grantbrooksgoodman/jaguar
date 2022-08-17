//
//  AppDelegate.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Contacts
import CoreTelephony
import MessageUI

/* Third-party Frameworks */
import AlertKit
import Firebase
import FirebaseAuth
import PKHUD
import Translator

//==================================================//

/* MARK: - Top-level Variable Declarations */

//DateFormatters
public let masterDateFormatter = DateFormatter()
public let secondaryDateFormatter = DateFormatter()

//Dictionaries
public var callingCodeDictionary: [String: String]!
public var languageCodeDictionary: [String: String]!

//Strings
public var callingCode = ""
public var currentUserID = "" {
    didSet {
        UserDefaults.standard.setValue(currentUserID, forKey: "currentUserID")
        UserSerializer.shared.getUser(withIdentifier: currentUserID) { (returnedUser, errorDescriptor) in
            guard let user = returnedUser else {
                Logger.log(errorDescriptor ?? "An unknown error occurred.",
                           with: .fatalAlert,
                           metadata: [#file, #function, #line])
                return
            }
            
            currentUser = user
            
            languageCode = user.languageCode
            AKCore.shared.setLanguageCode(languageCode)
            
            TranslationSerializer.downloadTranslations()
            currentUser!.updateConversationData { (returnedConversations,
                                                   errorDescriptor) in
                guard let conversations = returnedConversations else {
                    Logger.log(errorDescriptor ?? "An unknown error occurred.",
                               metadata: [#file, #function, #line])
                    return
                }
                
                ConversationArchiver.addToArchive(conversations)
            }
        }
    }
}
public var languageCode = Locale.preferredLanguages[0].components(separatedBy: "-")[0] //["af", "ga", "sq", "it", "ar", "ja", "az", "kn", "eu", "ko", "bn", "la", "be", "lv", "bg", "lt", "ca", "mk", "zh-CN", "ms", "zh-TW", "mt", "hr", "no", "cs", "fa", "da", "pl", "nl", "pt", "ro", "eo", "ru", "et", "sr", "tl", "sk", "fi", "sl", "fr", "es", "gl", "sw", "ka", "sv", "de", "ta", "el", "te", "gu", "th", "ht", "tr", "iw", "uk", "hi", "ur", "hu", "vi", "is", "cy", "id", "yi"].randomElement()! //["ca", "es", "fr", "gl", "it", "pt", "ro"].randomElement()! //Locale.preferredLanguages[0].components(separatedBy: "-")[0]

public var previousLanguageCode = ""
public var selectedRegionCode: String?

//Other Declarations
public let telephonyNetworkInfo = CTTelephonyNetworkInfo()

public var conversationArchive = [Conversation]() {
    didSet {
        ConversationArchiver.setArchive()
    }
}
public var currentCalendar = Calendar(identifier: .gregorian)
public var currentTimeLastCalled: Date! = Date() {
    willSet {
        print("\(newValue.amountOfSeconds(from: currentTimeLastCalled)) seconds from last call")
    }
}
public var currentUser: User?
public var isPresentingMailComposeViewController = false
public var selectedContact: CNContact?

//==================================================//

@UIApplicationMain public class AppDelegate: UIResponder, MFMailComposeViewControllerDelegate, UIApplicationDelegate {
    
    //==================================================//
    
    /* MARK: - Required Functions */
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Build.set([.appStoreReleaseVersion: 4,
                   .codeName: "Jaguar",
                   .dmyFirstCompileDateString: "23042022",
                   .finalName: "",
                   .stage: Build.Stage.alpha,
                   .timebombActive: true])
        
        Logger.exposureLevel = .normal
        
        let expiryAlertProvider = ExpiryAlertProvider()
        let reportProvider = ReportProvider()
        let translationProvider = TranslationProvider()
        
        AKCore.shared.setLanguageCode(languageCode)
        AKCore.shared.register(expiryAlertProvider: expiryAlertProvider,
                               reportProvider: reportProvider,
                               translationProvider: translationProvider)
        
        currentCalendar.timeZone = TimeZone(abbreviation: "GMT")!
        
        masterDateFormatter.dateFormat = "yyyy-MM-dd"
        masterDateFormatter.locale = Locale(identifier: "en_GB")
        
        secondaryDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        secondaryDateFormatter.locale = Locale(identifier: "en_GB")
        
        if let essentialLocalizations = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "EssentialLocalizations", ofType: "plist") ?? "") as? [String: [String: String]] {
            languageCodeDictionary = essentialLocalizations["language_codes"]!
            
            if languageCodeDictionary[languageCode] == nil {
                languageCode = "en"
                
                Logger.log("Unsupported language code; reverting to English.",
                           metadata: [#file, #function, #line])
            }
        } else {
            Logger.log("Essential localizations missing.",
                       with: .fatalAlert,
                       metadata: [#file, #function, #line])
        }
        
        if let callingCodes = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "CallingCodes", ofType: "plist") ?? "") as? [String: String] {
            callingCodeDictionary = callingCodes
        } else {
            Logger.log("Calling codes missing.",
                       with: .fatalAlert,
                       metadata: [#file, #function, #line])
        }
        
        callingCode = getCallingCode() ?? ""
        
        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.min)
        
        //        UserDefaults.standard.setValue(nil, forKey: "translationArchive")
        
        //        UserDefaults.standard.setValue(nil, forKey: "currentUserID")
        
        //        if let userID = UserDefaults.standard.value(forKey: "currentUserID") as? String {
        //            currentUserID = userID
        //        }
        
        ConversationArchiver.getArchive { (returnedTuple,
                                           errorDescriptor) in
            guard let tuple = returnedTuple else {
                Logger.log(errorDescriptor ?? "An unknown error occurred.",
                           metadata: [#file, #function, #line])
                return
            }
            
            if tuple.userID == currentUserID {
                conversationArchive = tuple.conversations.filter({ $0.participants.contains(where: { $0.userID == currentUserID })})
            } else {
                Logger.log("Different user ID – nuking conversation archive.",
                           metadata: [#file, #function, #line])
                
                conversationArchive = []
                UserDefaults.standard.setValue(nil, forKey: "conversationArchive")
                UserDefaults.standard.setValue(nil, forKey: "conversationArchiveUserID")
            }
        }
        
        return true
    }
    
    public func applicationDidBecomeActive(_ application: UIApplication) {
        
    }
    
    public func applicationDidEnterBackground(_ application: UIApplication) {
        
    }
    
    public func applicationWillEnterForeground(_ application: UIApplication) {
        
    }
    
    public func applicationWillResignActive(_ application: UIApplication) {
        
    }
    
    public func applicationWillTerminate(_ application: UIApplication) {
        
    }
    
    //==================================================//
    
    /* MARK: - Push Notification Functions */
    
    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
    }
    
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }
    
    public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        
        return false
    }
}

//==================================================//

/* MARK: - Helper Functions */

/**/

/* MARK: Dispatch Queue Functions */

public func after(milliseconds: Int, do: @escaping () -> Void = { }) {
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(milliseconds), execute: {
        `do`()
    })
}

public func after(seconds: Int, do: @escaping () -> Void = { }) {
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds), execute: {
        `do`()
    })
}

//--------------------------------------------------//

/* MARK: First Responder Functions */

///Finds and resigns the first responder.
public func findAndResignFirstResponder() {
    DispatchQueue.main.async {
        if let unwrappedFirstResponder = findFirstResponder(inView: AKCore.shared.getFrontmostVC().view) {
            unwrappedFirstResponder.resignFirstResponder()
        }
    }
}

///Finds the first responder in a given view.
public func findFirstResponder(inView view: UIView) -> UIView? {
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
public func hideHUD() {
    DispatchQueue.main.async {
        if PKHUD.sharedHUD.isVisible {
            PKHUD.sharedHUD.hide(true)
        }
    }
}

public func hideHUD(delay: Double?) {
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

public func hideHUD(delay: Double?, completion: @escaping() -> Void) {
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
public func showProgressHUD() {
    DispatchQueue.main.async {
        if !PKHUD.sharedHUD.isVisible {
            PKHUD.sharedHUD.contentView = PKHUDProgressView()
            PKHUD.sharedHUD.show(onView: AKCore.shared.getFrontmostVC().view)
        }
    }
}

public func showProgressHUD(text: String?, delay: Double?) {
    if let delay = delay {
        let millisecondDelay = Int(delay * 1000)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(millisecondDelay)) {
            if !PKHUD.sharedHUD.isVisible {
                PKHUD.sharedHUD.contentView = PKHUDProgressView(title: nil, subtitle: text)
                PKHUD.sharedHUD.show(onView: AKCore.shared.getFrontmostVC().view)
            }
        }
    } else {
        DispatchQueue.main.async {
            if !PKHUD.sharedHUD.isVisible {
                PKHUD.sharedHUD.contentView = PKHUDProgressView(title: nil, subtitle: text)
                PKHUD.sharedHUD.show(onView: AKCore.shared.getFrontmostVC().view)
            }
        }
    }
}

//--------------------------------------------------//

/* MARK: - Miscellaneous Functions */

///Retrieves the appropriately random tag integer for a given title.
public func aTagFor(_ theViewNamed: String) -> Int {
    var finalValue: Float = 1.0
    
    for individualCharacter in String(theViewNamed.unicodeScalars.filter(CharacterSet.letters.contains)).characterArray {
        finalValue += (finalValue / Float(individualCharacter.alphabeticalPosition))
    }
    
    return Int(String(finalValue).replacingOccurrences(of: ".", with: "")) ?? Int().random(min: 5, max: 10)
}

public func attributedString(_ with: String,
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

public func getCallingCode() -> String? {
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

public func messagesAttributedString(_ forString: String,
                                     separationIndex: Int) -> NSAttributedString {
    let attributedString = NSMutableAttributedString(string: forString)
    
    let boldAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 12),
                                                         .foregroundColor: UIColor.gray]
    
    let regularAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12),
                                                            .foregroundColor: UIColor.lightGray]
    
    attributedString.addAttributes(boldAttributes, range: NSRange(location: 0,
                                                                  length: separationIndex))
    
    attributedString.addAttributes(regularAttributes, range: NSRange(location: separationIndex,
                                                                     length: attributedString.length - separationIndex))
    
    return attributedString
}

///Presents a given view controller, but waits for others to be dismissed before doing so.
public func politelyPresent(viewController: UIViewController) {
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
            topController = AKCore.shared.getFrontmostVC()
            
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

public func printCurrentTime() {
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm:ss zzz"
    
    currentTimeLastCalled = Date()
    
    let timeString = timeFormatter.string(from: Date())
    print(timeString)
}

///Rounds the corners on any desired view.
///Numbers 0 through 4 correspond to all, left, right, top, and bottom, respectively.
public func roundCorners(forViews: [UIView], withCornerType: Int!) {
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
