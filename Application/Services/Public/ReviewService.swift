//
//  ReviewService.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 31/05/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import StoreKit

public struct ReviewService {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public static var canPromptToReview: Bool {
        get {
            guard lastRequestedReviewForBuildNumber != Build.buildNumber,
                  appOpenCount == 10 || appOpenCount == 50 || appOpenCount % 100 == 0 else { return false }
            return true
        }
    }
    
    private static let defaults = UserDefaults.standard
    
    private static var appOpenCount: Int {
        guard let appOpenCount = defaults.value(forKey: UserDefaultsKeys.appOpenCountKey) as? Int else {
            incrementAppOpenCount()
            return 1
        }
        
        return appOpenCount
    }
    
    private static var lastRequestedReviewForBuildNumber: Int {
        get {
            guard let buildNumber = defaults.value(forKey: UserDefaultsKeys.lastRequestedReviewForBuildNumberKey) as? Int else {
                defaults.set(Build.buildNumber, forKey: UserDefaultsKeys.lastRequestedReviewForBuildNumberKey)
                return 0
            }
            
            return buildNumber
        }
    }
    
    //==================================================//
    
    /* MARK: - Methods */
    
    public static func incrementAppOpenCount() {
        guard var appOpenCount = defaults.value(forKey: UserDefaultsKeys.appOpenCountKey) as? Int else {
            defaults.set(1, forKey: UserDefaultsKeys.appOpenCountKey)
            return
        }
        
        appOpenCount += 1
        defaults.set(appOpenCount, forKey: UserDefaultsKeys.appOpenCountKey)
    }
    
    public static func promptToReview() {
#if !EXTENSION
        guard canPromptToReview,
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
#endif
        defaults.set(Build.buildNumber, forKey: UserDefaultsKeys.lastRequestedReviewForBuildNumberKey)
    }
}
