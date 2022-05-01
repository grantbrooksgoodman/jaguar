//
//  AKAction.swift
//  AlertKit
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

/**
 Represents an action to be displayed as a button on a `UIAlertController`.
 */
public class AKAction {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    //Other Declarations
    let identifier: Int
    
    var style: AKActionStyle
    var title: String
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
    public init(title: String,
                style: AKActionStyle) {
        self.title = title
        self.style = style
        self.identifier = Int().random(min: 1000000, max: 9999999)
    }
}

//==================================================//

/* MARK: - Enumerated Type Declarations */

public enum AKActionStyle: Int {
    case `default` = 0
    case preferred = 1
    case destructive = 2
    case destructivePreferred = 3
}
