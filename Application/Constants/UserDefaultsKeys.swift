//
//  UserDefaultsKeys.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 31/05/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public struct UserDefaultsKeys {
    
    // Standard
    public static let currentThemeKey = "currentTheme"
    public static let developerModeEnabledKey = "developerModeEnabled"
    public static let hidesBuildInfoOverlayKey = "hidesBuildInfoOverlay"
    public static let pendingThemeNameKey = "pendingThemeName"
    
    // Miscellaneous
    public static let acknowledgedAudioMessagesUnsupportedKey = "acknowledgedAudioMessagesUnsupported"
    public static let clearedCachesKey = "clearedCaches"
    public static let currentUserIdKey = "currentUserID"
    public static let didResetForFirstRunKey = "didResetForFirstRun"
    public static let firebaseEnvironmentKey = "firebaseEnvironment"
    
    // ReviewService
    public static let appOpenCountKey = "appOpenCount"
    public static let lastRequestedReviewForBuildNumberKey = "lastRequestedReviewForBuildNumber"
    
    // Hash Archive
    public static let archivedLocalUserHashesKey = "archivedLocalUserHashes"
    public static let archivedServerUserHashesKey = "archivedServerUserHashes"
    public static let mismatchedHashesKey = "mismatchedHashes"
    
    // UpdateService
    public static let buildNumberWhenLastForcedToUpdateKey = "buildNumberWhenLastForcedToUpdate"
    public static let firstPostponedUpdateKey = "firstPostponedUpdate"
    public static let relaunchesSinceLastPostponedKey = "relaunchesSinceLastPostponed"
    
    // UserTestingSerializer
    public static let userListKey = "userList"
    public static let userListPositionKey = "userListPosition"
}
