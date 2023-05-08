//
//  ThemeService.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit
import SwiftUI

/* Third-party Frameworks */
import AlertKit

public struct ThemeService {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private(set) static var currentTheme = AppThemes.default {
        didSet {
            UserDefaults.standard.set(currentTheme.name, forKey: "currentTheme")
            ColorProvider.shared.updateColorState()
            ColorProvider.shared.currentThemeName = currentTheme.name
        }
    }
    
    //==================================================//
    
    /* MARK: - Setter Method */
    
    public static func setTheme(_ theme: UITheme, checkStyle: Bool = true) {
        guard checkStyle else {
            currentTheme = theme
            return
        }
        
        guard currentTheme.style == theme.style else {
            AKAlert(message: "The new appearance will take effect the next time you restart the app.",
                    cancelButtonTitle: "Dismiss").present { _ in
                UserDefaults.standard.set(theme.name, forKey: "pendingThemeName")
            }
            
            return
        }
        
        currentTheme = theme
    }
}
