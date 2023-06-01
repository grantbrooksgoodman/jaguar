//
//  UpdateService.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 27/04/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

/* Third-party Frameworks */
import AlertKit

public struct UpdateService {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Integers
    
    private(set) static var buildNumberWhenLastForcedToUpdate: Int? {
        didSet {
            UserDefaults.standard.set(buildNumberWhenLastForcedToUpdate, forKey: UserDefaultsKeys.buildNumberWhenLastForcedToUpdateKey)
        }
    }
    
    private(set) static var relaunchesSinceLastPostponed = 0 {
        didSet {
            UserDefaults.standard.set(relaunchesSinceLastPostponed, forKey: UserDefaultsKeys.relaunchesSinceLastPostponedKey)
        }
    }
    
    // Other
    
    public enum UpdateType {
        case normal
        case forced
    }
    
    private(set) static var firstPostponedUpdate: Date? {
        didSet {
            guard let firstPostponedUpdate else {
                UserDefaults.standard.set(nil, forKey: UserDefaultsKeys.firstPostponedUpdateKey)
                return
            }
            
            let dateString = Core.masterDateFormatter.string(from: firstPostponedUpdate)
            UserDefaults.standard.set(dateString, forKey: UserDefaultsKeys.firstPostponedUpdateKey)
        }
    }
    
    private static var hasUpdatedSinceLastForce: Bool {
        get {
            guard let buildNumberWhenLastForcedToUpdate else { return true }
            guard buildNumberWhenLastForcedToUpdate == Build.buildNumber else {
                self.buildNumberWhenLastForcedToUpdate = nil
                return true
            }
            
            return false
        }
    }
    
    //==================================================//
    
    /* MARK: - Public Methods */
    
    public static func checkForUpdates(completion: @escaping(_ shouldPrompt: Bool?,
                                                             _ forceUpdate: Bool?,
                                                             _ exception: Exception?) -> Void) {
        guard let appStoreBuildNumber = MetadataService.appStoreBuildNumber,
              let overrideForceUpdate = MetadataService.shouldForceUpdate else {
            MetadataService.setKeys { exception in
                guard exception == nil else {
                    completion(nil, nil, exception!)
                    return
                }
                
                self.checkForUpdates { shouldPrompt, forceUpdate, exception in
                    completion(shouldPrompt, forceUpdate, exception)
                }
            }
            
            return
        }
        
        let updateAvailable = appStoreBuildNumber > Build.buildNumber
        let shouldPrompt = relaunchesSinceLastPostponed >= 3
        
        guard !overrideForceUpdate else {
            completion(updateAvailable, true, nil)
            return
        }
        
        guard hasUpdatedSinceLastForce else {
            completion(updateAvailable, true, nil)
            return
        }
        
        guard let firstPostponedUpdate else {
            completion(updateAvailable, false, nil)
            return
        }
        
        let interval = Core.currentCalendar!.dateComponents([.day],
                                                            from: firstPostponedUpdate.comparator,
                                                            to: Date().comparator)
        guard let daysPassed = interval.day else {
            completion(updateAvailable && shouldPrompt, false, nil)
            return
        }
        
        if daysPassed < 0 {
            self.firstPostponedUpdate = nil
            relaunchesSinceLastPostponed = 0
            buildNumberWhenLastForcedToUpdate = nil
        }
        
        guard daysPassed >= 10 else {
            completion(updateAvailable && shouldPrompt, false, nil)
            return
        }
        
        completion(updateAvailable, true, nil)
    }
    
    public static func presentCTA(forUpdateType type: UpdateType, completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        guard let appShareLink = MetadataService.appShareLink else {
            MetadataService.setKeys { exception in
                guard exception == nil else {
                    completion(exception!)
                    return
                }
                
                self.presentCTA(forUpdateType: type) { exception in completion(exception) }
            }
            
            return
        }
        
#if !EXTENSION
        guard let topViewController = UIApplication.topViewController(),
              !topViewController.isKind(of: UIAlertController.self) else {
            completion(nil)
            return
        }
#endif
        
        switch type {
        case .normal:
            presentNormalUpdateCTA(appShareLink) { completion(nil) }
        case .forced:
            presentForcedUpdateCTA(appShareLink) { completion(nil) }
        }
    }
    
    // #warning("If we have this, all the other functions can be private.")
    public static func promptToUpdateIfNeeded(completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        checkForUpdates { shouldPrompt, forceUpdate, exception in
            guard let shouldPrompt, let forceUpdate else {
                completion(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            guard shouldPrompt else {
                completion(nil)
                return
            }
            
            if forceUpdate {
                presentCTA(forUpdateType: .forced) { exception in completion(exception) }
            } else {
                presentCTA(forUpdateType: .normal) { exception in completion(exception) }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Setter Methods */
    
    public static func setBuildNumberWhenLastForcedToUpdate(_ buildNumber: Int) {
        buildNumberWhenLastForcedToUpdate = buildNumber
    }
    
    public static func setFirstPostponedUpdate(_ date: Date) {
        firstPostponedUpdate = date
    }
    
    public static func setRelaunchesSinceLastPostponed(_ relaunches: Int) {
        relaunchesSinceLastPostponed = relaunches
    }
    
    //==================================================//
    
    /* MARK: - CTA Methods */
    
    private static func persistForcedUpdateCTA() {
        Core.gcd.after(milliseconds: 500) {
#if !EXTENSION
            guard let topViewController = UIApplication.topViewController(),
                  !topViewController.isKind(of: UIAlertController.self) else {
                Core.gcd.after(seconds: 2) { self.persistForcedUpdateCTA() }
                return
            }
#endif
            
            self.presentCTA(forUpdateType: .forced)
        }
    }
    
    private static func presentForcedUpdateCTA(_ url: URL, completion: @escaping() -> Void) {
        RuntimeStorage.topWindow?.isUserInteractionEnabled = true
        
        let message = "This version of *Hello* is no longer supported. To continue, please download and install the most recent update."
        
        AKAlert(title: "Update Required",
                message: message,
                actions: [AKAction(title: "Update", style: .preferred)],
                showsCancelButton: Build.developerModeEnabled || Build.stage != .generalRelease).present { actionID in
            guard actionID != -1 else {
                firstPostponedUpdate = nil
                relaunchesSinceLastPostponed = 0
                buildNumberWhenLastForcedToUpdate = nil
                return
            }
            
            RuntimeStorage.topWindow?.isUserInteractionEnabled = false
            
            Core.open(url)
            
            buildNumberWhenLastForcedToUpdate = Build.buildNumber
            
            firstPostponedUpdate = nil
            relaunchesSinceLastPostponed = 0
            
            persistForcedUpdateCTA()
            completion()
        }
    }
    
    private static func presentNormalUpdateCTA(_ url: URL, completion: @escaping() -> Void) {
        let message = "A new version of *Hello* is available in the *App Store*. Would you like to update now?"
        
        AKAlert(title: "Update Available",
                message: message,
                actions: [AKAction(title: "Update", style: .preferred)],
                cancelButtonTitle: "Later").present { actionID in
            guard actionID != -1 else {
                if firstPostponedUpdate == nil {
                    firstPostponedUpdate = Date()
                }
                
                relaunchesSinceLastPostponed = 0
                completion()
                return
            }
            
            Core.open(url)
            
            firstPostponedUpdate = nil
            relaunchesSinceLastPostponed = 0
            completion()
        }
    }
}
