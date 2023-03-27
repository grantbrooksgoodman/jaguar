//
//  AppDelegate.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import AudioToolbox
import CoreTelephony

/* Third-party Frameworks */
import AlertKit
import Firebase
import FirebaseAuth
import FirebaseMessaging
import Translator

//==================================================//

/* MARK: - Top-level Properties */

public let telephonyNetworkInfo = CTTelephonyNetworkInfo()

//==================================================//

@UIApplicationMain public class AppDelegate: UIResponder, UIApplicationDelegate {
    
    //==================================================//
    
    /* MARK: - UIApplication Methods */
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        preInitialize()
        resetForFirstRunIfNeeded(environment: .staging)
        
        setUpRuntimeStorage()
        setEnvironment()
        
        setUpCallingCodes()
        
        setUpFirebase()
        setUpPushNotifications()
        
        setUpContactArchive()
        setUpConversationArchive()
        
        setUpUserHashes()
        
        return true
    }
    
    public func applicationWillTerminate(_ application: UIApplication) {
        AnalyticsService.logEvent(.terminateApp)
    }
    
    //==================================================//
    
    /* MARK: - Setup/Initialization Methods */
    
    private func resetForFirstRunIfNeeded(environment: GeneralSerializer.Environment = .production) {
        guard Build.stage != .generalRelease else { return }
        
        if let didResetForFirstRun = UserDefaults.standard.value(forKey: "didResetForFirstRun") as? Bool {
            RuntimeStorage.store(didResetForFirstRun, as: .didResetForFirstRun)
        } else {
            RuntimeStorage.store(false, as: .didResetForFirstRun)
            UserDefaults.standard.set(false, forKey: "didResetForFirstRun")
        }
        
        guard !RuntimeStorage.didResetForFirstRun! else { return }
        
        Core.gcd.after(milliseconds: 100) {
            Logger.log("Resetting application for first run.",
                       metadata: [#file, #function, #line])
        }
        
        UserDefaults.reset()
        ContactArchiver.clearArchive()
        ContactService.clearCache()
        ConversationArchiver.clearArchive()
        RecognitionService.clearCache()
        TranslationArchiver.clearArchive()
        
        RuntimeStorage.store(true, as: .didResetForFirstRun)
        UserDefaults.standard.set(true, forKey: "didResetForFirstRun")
        
        UserDefaults.standard.set(environment.shortString, forKey: "firebaseEnvironment")
    }
    
    private func preInitialize() {
        /* MARK: Build & Logger Setup */
        
        RuntimeStorage.store(Locale.preferredLanguages[0].components(separatedBy: "-")[0],
                             as: .languageCode)
        
        var developerModeEnabled = false
        if let developerMode = UserDefaults.standard.value(forKey: "developerModeEnabled") as? Bool {
            developerModeEnabled = developerMode
        }
        
        Build.set([.appStoreReleaseVersion: 0,
                   .codeName: "Jaguar",
                   .developerModeEnabled: developerModeEnabled,
                   .dmyFirstCompileDateString: "23042022",
                   .finalName: "Hello",
                   .loggingEnabled: false,
                   .stage: Build.Stage.releaseCandidate,
                   .timebombActive: true])
        
        if Build.stage == .generalRelease {
            Build.set(.developerModeEnabled, to: false)
        }
        
        UserDefaults.standard.setValue(Build.stage == .generalRelease ? false : developerModeEnabled,
                                       forKey: "developerModeEnabled")
        
        Logger.exposureLevel = .verbose
        DevModeService.addStandardActions()
        
        /* MARK: AlertKit Setup */
        
        let expiryAlertDelegate = ExpiryAlertDelegate()
        let reportDelegate = ReportDelegate()
        let translationDelegate = TranslationDelegate()
        
        AKCore.shared.setLanguageCode(RuntimeStorage.languageCode!)
        AKCore.shared.register(expiryAlertDelegate: expiryAlertDelegate,
                               reportDelegate: reportDelegate,
                               translationDelegate: translationDelegate)
        
        /* MARK: Localization Setup */
        
        guard let essentialLocalizations = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "EssentialLocalizations", ofType: "plist") ?? "") as? [String: [String: String]] else {
            Logger.log("Essential localizations missing.",
                       with: .fatalAlert,
                       metadata: [#file, #function, #line])
            return
        }
        
        RuntimeStorage.store(essentialLocalizations["language_codes"]!, as: .languageCodeDictionary)
        
        guard let languageCodeDictionary = RuntimeStorage.languageCodeDictionary else {
            Logger.log("No language code dictionary!",
                       metadata: [#file, #function, #line])
            return
        }
        
        guard languageCodeDictionary[RuntimeStorage.languageCode!] != nil else {
            RuntimeStorage.store("en", as: .overriddenLanguageCode)
            AKCore.shared.lockLanguageCode(to: "en")
            
            Logger.log("Unsupported language code; reverting to English.",
                       metadata: [#file, #function, #line])
            return
        }
    }
    
    private func setUpRuntimeStorage() {
        StateProvider.shared.hasDisappeared = false
        
        RuntimeStorage.store(false, as: .acknowledgedAudioMessagesUnsupported)
        RuntimeStorage.store(false, as: .isPresentingChat)
        RuntimeStorage.store(false, as: .isSendingMessage)
        RuntimeStorage.store(false, as: .receivedNotification)
        RuntimeStorage.store(false, as: .shouldReloadData)
        RuntimeStorage.store(false, as: .shouldReloadForFirstConversation)
        RuntimeStorage.store(false, as: .shouldUpdateReadState)
        RuntimeStorage.store(false, as: .updatedPushToken)
        RuntimeStorage.store(false, as: .wantsToInvite)
        
        RuntimeStorage.store(#file, as: .currentFile)
        RuntimeStorage.store(0, as: .messageOffset)
        RuntimeStorage.store([], as: .mismatchedHashes)
        
        if let acknowledgedAudioMessagesUnsupported = UserDefaults.standard.value(forKey: "acknowledgedAudioMessagesUnsupported") as? Bool {
            RuntimeStorage.store(acknowledgedAudioMessagesUnsupported, as: .acknowledgedAudioMessagesUnsupported)
        }
        
        if let mismatchedHashes = UserDefaults.standard.value(forKey: "mismatchedHashes") as? [String] {
            RuntimeStorage.store(mismatchedHashes, as: .mismatchedHashes)
        }
    }
    
    private func setEnvironment(to environment: GeneralSerializer.Environment? = nil) {
        guard Build.stage != .generalRelease else {
            GeneralSerializer.environment = .production
            UserDefaults.standard.set(GeneralSerializer.environment.shortString, forKey: "firebaseEnvironment")
            return
        }
        
        guard let environment else {
            if let environmentString = UserDefaults.standard.string(forKey: "firebaseEnvironment"),
               let environment = environmentString.asEnvironment {
                GeneralSerializer.environment = environment
            }
            return
        }
        
        GeneralSerializer.environment = environment
        UserDefaults.standard.set(GeneralSerializer.environment.shortString, forKey: "firebaseEnvironment")
    }
    
    private func setUpCallingCodes() {
        if let callingCodes = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "CallingCodes", ofType: "plist") ?? "") as? [String: String] {
            RuntimeStorage.store(callingCodes, as: .callingCodeDictionary)
        } else {
            Logger.log("Calling codes missing.",
                       with: .fatalAlert,
                       metadata: [#file, #function, #line])
        }
        
        if let lookupTables = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "LookupTables", ofType: "plist") ?? "") as? [String: [String]] {
            RuntimeStorage.store(lookupTables, as: .lookupTableDictionary)
        } else {
            Logger.log("Lookup tables missing.",
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
        
#if !EXTENSION
        FirebaseAnalytics.Analytics.setAnalyticsCollectionEnabled(true)
#endif
        
        AnalyticsService.logEvent(.openApp)
    }
    
    private func setUpPushNotifications() {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
    }
    
    private func setUpContactArchive() {
        ContactArchiver.getArchive { _, exception in
            guard let error = exception else { return }
            
            Logger.log(error)
        }
    }
    
    private func setUpConversationArchive() {
        ConversationArchiver.getArchive { _, exception in
            guard let error = exception else { return }
            
            Logger.log(error)
        }
    }
    
    private func setUpUserHashes() {
        if let archivedHashes = UserDefaults.standard.value(forKey: "archivedServerUserHashes") as? [String] {
            RuntimeStorage.store(archivedHashes, as: .archivedServerUserHashes)
        } else {
            // #warning("Maybe this should be async?")
            ContactService.getServerUserHashes { hashes, exception in
                guard let updatedServerUserHashes = hashes else {
                    Logger.log(exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                UserDefaults.standard.set(updatedServerUserHashes, forKey: "archivedServerUserHashes")
                RuntimeStorage.store(updatedServerUserHashes, as: .archivedServerUserHashes)
            }
        }
        
        guard let localUserHashes = UserDefaults.standard.value(forKey: "archivedLocalUserHashes") as? [String] else { return }
        RuntimeStorage.store(localUserHashes, as: .archivedLocalUserHashes)
    }
    
    //==================================================//
    
    /* MARK: - Push Notification Methods */
    
    public func application(_: UIApplication,
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Logger.log(Exception(error, metadata: [#file, #function, #line]))
    }
    
    public func application(_: UIApplication,
                            didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                            fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
    }
    
    public func application(_: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    public func application(_: UIApplication,
                            open url: URL,
                            options _: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return Auth.auth().canHandle(url)
    }
    
    //==================================================//
    
    /* MARK: - Miscellaneous Methods */
    
    private func getCallingCode() -> String? {
        guard let callingCodes = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "CallingCodes", ofType: "plist") ?? "") as? [String: String] else { return nil }
        
        guard let carrier = telephonyNetworkInfo.serviceSubscriberCellularProviders?.first?.value,
              let countryCode = carrier.isoCountryCode else {
            guard let countryCode = (Locale.current as NSLocale).object(forKey: .countryCode) as? String,
                  let callingCode = callingCodes[countryCode.uppercased()] else { return nil }
            
            return callingCode
        }
        
        return callingCodes[countryCode.uppercased()]
    }
}

//==================================================//

/* MARK: - Protocol Conformances */

/**/

/* MARK: MessagingDelegate */
extension AppDelegate: MessagingDelegate {
    public func messaging(_ messaging: Messaging,
                          didReceiveRegistrationToken fcmToken: String?) {
        let tokenDict = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"),
                                        object: nil,
                                        userInfo: tokenDict)
        guard let token = fcmToken else {
            return
        }
        
        RuntimeStorage.store(token, as: .pushToken)
    }
}

/* MARK: UNUserNotificationCenterDelegate */
extension AppDelegate: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler:
                                       @escaping (UNNotificationPresentationOptions) -> Void) {
#if !EXTENSION
        switch UIApplication.shared.applicationState {
        case .background, .inactive:
            UIApplication.shared.applicationIconBadgeNumber += 1
            completionHandler([[.banner, .sound, .badge]])
        case .active:
            //            let userInfo = notification.request.content.userInfo
            //            guard let pushServiceContent = userInfo["aps"] as? [AnyHashable: Any],
            //                  let alertContent = pushServiceContent["alert"] as? [AnyHashable: Any],
            //                  let title = alertContent["title"] as? String,
            //                  let body = alertContent["body"] as? String else { return }
            
            RuntimeStorage.store(true, as: .receivedNotification)
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            RuntimeStorage.conversationsPageViewModel?.reloadIfNeeded()
        @unknown default:
            UIApplication.shared.applicationIconBadgeNumber += 1
            completionHandler([[.banner, .sound, .badge]])
        }
#endif
    }
}
