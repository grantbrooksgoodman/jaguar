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
        
        let currentTheme = defaults.value(forKey: "currentTheme") as? String
        let developerModeEnabled = defaults.value(forKey: "developerModeEnabled") as? Bool
        let didResetForFirstRun = defaults.value(forKey: "didResetForFirstRun") as? Bool
        let firebaseEnvironment = defaults.value(forKey: "firebaseEnvironment") as? String
        let hidesBuildInfoOverlay = defaults.value(forKey: "hidesBuildInfoOverlay") as? Bool
        let dictionary = defaults.dictionaryRepresentation()
        
        dictionary.keys.forEach { key in
            defaults.removeObject(forKey: key)
        }
        
        if let currentTheme {
            defaults.set(currentTheme, forKey: "currentTheme")
        }
        
        if let developerModeEnabled {
            defaults.set(developerModeEnabled, forKey: "developerModeEnabled")
        }
        
        if let didResetForFirstRun {
            defaults.set(didResetForFirstRun, forKey: "didResetForFirstRun")
        }
        
        if let firebaseEnvironment {
            defaults.set(firebaseEnvironment, forKey: "firebaseEnvironment")
        }
        
        if let hidesBuildInfoOverlay {
            defaults.set(hidesBuildInfoOverlay, forKey: "hidesBuildInfoOverlay")
        }
    }
}
