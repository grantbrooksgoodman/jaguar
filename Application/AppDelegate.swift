//
//  AppDelegate.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import CoreTelephony

/* Third-party Frameworks */
import AlertKit
import Firebase
import FirebaseAuth
import PKHUD
import Translator

//==================================================//

/* MARK: - Top-level Properties */

// Other
public let telephonyNetworkInfo = CTTelephonyNetworkInfo()

public var currentTimeLastCalled: Date! = Date() {
    willSet {
        print("\(newValue.amountOfSeconds(from: currentTimeLastCalled)) seconds from last call")
    }
}

//==================================================//

@UIApplicationMain public class AppDelegate: UIResponder, UIApplicationDelegate {
    
    //==================================================//
    
    /* MARK: - UIApplication Functions */
    
    public func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        preInitialize()
        
        setUpCallingCodes()
        setUpFirebase()
        
        UserDefaults.standard.setValue(nil, forKey: "currentUserID")
        
        RuntimeStorage.store(false, as: .shouldUseRandomUser)
        RuntimeStorage.store(#file, as: .currentFile)
        
        RuntimeStorage.store([], as: .conversations)
        RuntimeStorage.store(false, as: .shouldReloadData)
        RuntimeStorage.store(0, as: .messageOffset)
        
        //        if !RuntimeStorage.shouldUseRandomUser! {
        //            #if targetEnvironment(simulator)
        //            currentUserID = "QDpQ8qwwdMOS98QcEMjL9aV1oPn1"
        ////            currentUserID = "fiIvyzSPnVfVAj14GuXTUctwMh22"
        //            #else
        //            currentUserID = "QDpQ8qwwdMOS98QcEMjL9aV1oPn1"
        //            #endif
        //        }
        
        setUpConversationArchive()
        
        ContactArchiver.clearArchive()
        setUpContactArchive()
        
        return true
    }
    
    //==================================================//
    
    /* MARK: - Setup/Initialization Functions */
    
    private func preInitialize() {
        /* MARK: Build & Logger Setup */
        
        RuntimeStorage.store(Locale.preferredLanguages[0].components(separatedBy: "-")[0],
                             as: .languageCode)
        
        Build.set([.appStoreReleaseVersion: 0,
                   .codeName: "Jaguar",
                   .dmyFirstCompileDateString: "23042022",
                   .finalName: "Hello",
                   .stage: Build.Stage.beta,
                   .timebombActive: true])
        
        Logger.exposureLevel = .verbose
        
        
        /* MARK: AlertKit Setup */
        
        let expiryAlertProvider = ExpiryAlertProvider()
        let reportProvider = ReportProvider()
        let translationProvider = TranslationProvider()
        
        AKCore.shared.setLanguageCode(RuntimeStorage.languageCode!)
        AKCore.shared.register(expiryAlertProvider: expiryAlertProvider,
                               reportProvider: reportProvider,
                               translationProvider: translationProvider)
        
        /* MARK: Localization Setup */
        
        if let essentialLocalizations = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "EssentialLocalizations", ofType: "plist") ?? "") as? [String: [String: String]] {
            RuntimeStorage.store(essentialLocalizations["language_codes"]!, as: .languageCodeDictionary)
            
            guard let languageCodeDictionary = RuntimeStorage.languageCodeDictionary else {
                Logger.log("No language code dictionary!",
                           metadata: [#file, #function, #line])
                return
            }
            
            if languageCodeDictionary[RuntimeStorage.languageCode!] == nil {
                RuntimeStorage.store("en", as: .languageCode)
                
                Logger.log("Unsupported language code; reverting to English.",
                           metadata: [#file, #function, #line])
            }
        } else {
            Logger.log("Essential localizations missing.",
                       with: .fatalAlert,
                       metadata: [#file, #function, #line])
        }
    }
    
    private func setUpCallingCodes() {
        if let callingCodes = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "CallingCodes", ofType: "plist") ?? "") as? [String: String] {
            RuntimeStorage.store(callingCodes, as: .callingCodeDictionary)
        } else {
            Logger.log("Calling codes missing.",
                       with: .fatalAlert,
                       metadata: [#file, #function, #line])
        }
        
        RuntimeStorage.store(getCallingCode() ?? "", as: .callingCode)
    }
    
    private func setUpFirebase() {
        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.min)
        
        if let userID = UserDefaults.standard.value(forKey: "currentUserID") as? String {
            RuntimeStorage.store(userID, as: .currentUserID)
        }
    }
    
    private func setUpConversationArchive() {
        ConversationArchiver.getArchive { _, errorDescriptor in
            guard let error = errorDescriptor else {
                return
            }
            
            Logger.log(error,
                       metadata: [#file, #function, #line])
        }
    }
    
    private func setUpContactArchive() {
        ContactArchiver.getArchive { _, errorDescriptor in
            guard let error = errorDescriptor else {
                return
            }
            
            Logger.log(error,
                       metadata: [#file, #function, #line])
        }
    }
    
    //==================================================//
    
    /* MARK: - Push Notification Functions */
    
    public func application(_: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
    }
    
    public func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }
    
    public func application(_: UIApplication, open url: URL, options _: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        
        return false
    }
    
    //==================================================//
    
    /* MARK: - Miscellaneous Functions */
    
    private func getCallingCode() -> String? {
        guard let callingCodes = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "CallingCodes", ofType: "plist") ?? "") as? [String: String] else { return nil }
        
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
}

//==================================================//

/* MARK: - Miscellaneous Functions */

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

public func printCurrentTime() {
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm:ss zzz"
    
    currentTimeLastCalled = Date()
    
    let timeString = timeFormatter.string(from: Date())
    print(timeString)
}
