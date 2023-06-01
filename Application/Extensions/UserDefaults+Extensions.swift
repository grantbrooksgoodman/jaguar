//
//  UserDefaults+Extensions.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 27/04/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public extension UserDefaults {
    static func reset() {
        let defaults = UserDefaults.standard
        
        let currentTheme = defaults.value(forKey: UserDefaultsKeys.currentThemeKey) as? String
        let developerModeEnabled = defaults.value(forKey: UserDefaultsKeys.developerModeEnabledKey) as? Bool
        let didResetForFirstRun = defaults.value(forKey: UserDefaultsKeys.didResetForFirstRunKey) as? Bool
        let firebaseEnvironment = defaults.value(forKey: UserDefaultsKeys.firebaseEnvironmentKey) as? String
        let hidesBuildInfoOverlay = defaults.value(forKey: UserDefaultsKeys.hidesBuildInfoOverlayKey) as? Bool
        let dictionary = defaults.dictionaryRepresentation()
        
        dictionary.keys.forEach { key in
            defaults.removeObject(forKey: key)
        }
        
        if let currentTheme {
            defaults.set(currentTheme, forKey: UserDefaultsKeys.currentThemeKey)
        }
        
        if let developerModeEnabled {
            defaults.set(developerModeEnabled, forKey: UserDefaultsKeys.developerModeEnabledKey)
        }
        
        if let didResetForFirstRun {
            defaults.set(didResetForFirstRun, forKey: UserDefaultsKeys.didResetForFirstRunKey)
        }
        
        if let firebaseEnvironment {
            defaults.set(firebaseEnvironment, forKey: UserDefaultsKeys.firebaseEnvironmentKey)
        }
        
        if let hidesBuildInfoOverlay {
            defaults.set(hidesBuildInfoOverlay, forKey: UserDefaultsKeys.hidesBuildInfoOverlayKey)
        }
    }
}
