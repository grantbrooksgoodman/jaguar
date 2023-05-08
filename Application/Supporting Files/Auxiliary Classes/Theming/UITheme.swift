//
//  UITheme.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

public struct UITheme: Equatable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private(set) var name: String
    private(set) var items: [ColoredItem]
    private(set) var style: UIUserInterfaceStyle
    
    //==================================================//
    
    /* MARK: - Constructor */
    
    public init(name: String,
                items: [ColoredItem],
                style: UIUserInterfaceStyle = .unspecified) {
        self.name = name
        self.items = items
        self.style = style
        guard !containsDuplicates(items: self.items) else { fatalError("Cannot instantiate UITheme with duplicate ColoredItems") }
    }
    
    //==================================================//
    
    /* MARK: - Public Methods */
    
    /// - Warning: Returns `UIColor.clear` if item is not themed.
    public func color(for itemType: ColoredItemType) -> UIColor {
        guard let item = items.first(where: { $0.type == itemType }) else { return .clear }
        return UITraitCollection.current.userInterfaceStyle == .dark ? (item.set.variant ?? item.set.primary) : item.set.primary
    }
    
    //==================================================//
    
    /* MARK: - Equatable Conformance */
    
    public static func == (left: UITheme, right: UITheme) -> Bool {
        let sameName = left.name == right.name
        let sameItems = left.items == right.items
        let sameStyle = left.style == right.style
        
        return sameName && sameItems && sameStyle
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func containsDuplicates(items: [ColoredItem]) -> Bool {
        var seen = [ColoredItemType]()
        for item in items {
            guard !seen.contains(item.type) else { return true }
            seen.append(item.type)
        }
        
        return false
    }
}
