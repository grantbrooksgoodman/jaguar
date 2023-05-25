//
//  UITheme+Extensions.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 19/05/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public extension UITheme {
    var nonEnglishDescriptor: String? {
        switch name {
        case "Default":
            return "Normal"
        case "Bluesky":
            return "Blue"
        case "Dusk":
            return "Orange"
        case "Firebrand":
            return "Red"
        case "Twilight":
            return "Purple"
        default:
            return nil
        }
    }
}
