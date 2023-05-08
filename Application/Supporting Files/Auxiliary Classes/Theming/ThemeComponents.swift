//
//  ThemeComponents.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

public struct ColoredItem: Equatable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public let type: ColoredItemType
    public let set: ColorSet
    
    //==================================================//
    
    /* MARK: - Constructor */
    
    public init(type: ColoredItemType, set: ColorSet) {
        self.type = type
        self.set = set
    }
    
    //==================================================//
    
    /* MARK: - Equatable Conformance */
    
    public static func == (left: ColoredItem, right: ColoredItem) -> Bool {
        let sameType = left.type == right.type
        let sameSet = left.set == right.set
        
        return sameType && sameSet
    }
}

public struct ColorSet: Equatable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private(set) var primary: UIColor!
    private(set) var variant: UIColor?
    
    //==================================================//
    
    /* MARK: - Constructor */
    
    public init(primary: UIColor,
                variant: UIColor? = nil) {
        self.primary = primary
        self.variant = variant
    }
    
    //==================================================//
    
    /* MARK: - Equatable Conformance */
    
    public static func == (left: ColorSet, right: ColorSet) -> Bool {
        let samePrimary = left.primary == right.primary
        let sameVariant = left.variant == right.variant
        
        return samePrimary && sameVariant
    }
}
