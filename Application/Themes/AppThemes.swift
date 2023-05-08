//
//  AppThemes.swift
//  Application
//
//  Created by Grant Brooks Goodman on DD/MM/20YY.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

/**
 Use this enum to build new `UIThemes`.
 */
public enum AppThemes {
    
    //==================================================//
    
    /* MARK: - Theme List */
    
    public static var list: [UITheme] = [`default`, dusk, twilight, bluesky, firebrand]
    
    //==================================================//
    
    /* MARK: - Definitions */
    
    public static var `default`: UITheme {
        let accentColor = UIColor.systemBlue
        
        let encapsulatingView = ColoredItem(type: .encapsulatingView, set: ColorSet(primary: .clear))
        let accent = ColoredItem(type: .primaryAccent, set: ColorSet(primary: accentColor))
        
        let titleText = ColoredItem(type: .titleText, set: ColorSet(primary: .black, variant: .white))
        let subtitleText = ColoredItem(type: .subtitleText, set: ColorSet(primary: .gray))
        
        let senderBubble = ColoredItem(type: .senderBubble, set: ColorSet(primary: accentColor))
        let receiverBubble = ColoredItem(type: .receiverBubble, set: ColorSet(primary: UIColor(hex: 0xE5E5EA),
                                                                              variant: UIColor(hex: 0x27252A)))
        let untranslatedBubble = ColoredItem(type: .untranslatedBubble, set: ColorSet(primary: UIColor(hex: 0x65C466)))
        
        let navigationBarBackground = ColoredItem(type: .navigationBarBackground, set: ColorSet(primary: UIColor(hex: 0xF8F8F8),
                                                                                                variant: UIColor(hex: 0x2A2A2C)))
        let navigationBarTitle = ColoredItem(type: .navigationBarTitle, set: ColorSet(primary: .black, variant: .white))
        
        let inputBarBackground = ColoredItem(type: .inputBarBackground, set: ColorSet(primary: .white,
                                                                                      variant: UIColor(hex: 0x1A1A1C)))
        
        let listViewBackground = ColoredItem(type: .listViewBackground, set: ColorSet(primary: UIColor(hex: 0xF2F2F7),
                                                                                      variant: UIColor(hex: 0x1C1C1E)))
        
        let themedItems = [encapsulatingView,
                           accent,
                           titleText,
                           subtitleText,
                           senderBubble,
                           receiverBubble,
                           untranslatedBubble,
                           navigationBarBackground,
                           navigationBarTitle,
                           inputBarBackground,
                           listViewBackground]
        
        return UITheme(name: "Default", items: themedItems)
    }
    
    public static var dusk: UITheme {
        let accentColor = UIColor(hex: 0xFA8231)
        let backgroundColor = UIColor(hex: 0x1A1A1A)
        
        let encapsulatingView = ColoredItem(type: .encapsulatingView, set: ColorSet(primary: backgroundColor))
        let accent = ColoredItem(type: .primaryAccent, set: ColorSet(primary: accentColor))
        let titleText = ColoredItem(type: .titleText, set: ColorSet(primary: .white))
        let subtitleText = ColoredItem(type: .subtitleText, set: ColorSet(primary: .lightGray))
        let senderBubble = ColoredItem(type: .senderBubble, set: ColorSet(primary: accentColor))
        let receiverBubble = ColoredItem(type: .receiverBubble, set: ColorSet(primary: UIColor(hex: 0x27252A)))
        let untranslatedBubble = ColoredItem(type: .untranslatedBubble, set: ColorSet(primary: UIColor(hex: 0x65C466)))
        let navigationBarBackground = ColoredItem(type: .navigationBarBackground, set: ColorSet(primary: backgroundColor))
        let navigationBarTitle = ColoredItem(type: .navigationBarTitle, set: ColorSet(primary: accentColor))
        let inputBarBackground = ColoredItem(type: .inputBarBackground, set: ColorSet(primary: backgroundColor))
        let listViewBackground = ColoredItem(type: .listViewBackground, set: ColorSet(primary: UIColor(hex: 0x1C1C1E)))
        
        let themedItems = [encapsulatingView,
                           accent,
                           titleText,
                           subtitleText,
                           senderBubble,
                           receiverBubble,
                           untranslatedBubble,
                           navigationBarBackground,
                           navigationBarTitle,
                           inputBarBackground,
                           listViewBackground]
        
        return UITheme(name: "Dusk", items: themedItems, style: .dark)
    }
    
    public static var twilight: UITheme {
        let accentColor = UIColor(hex: 0x786DC4)
        let backgroundColor = UIColor(hex: 0x1A1A1A)
        
        let encapsulatingView = ColoredItem(type: .encapsulatingView, set: ColorSet(primary: backgroundColor))
        let accent = ColoredItem(type: .primaryAccent, set: ColorSet(primary: accentColor))
        let titleText = ColoredItem(type: .titleText, set: ColorSet(primary: .white))
        let subtitleText = ColoredItem(type: .subtitleText, set: ColorSet(primary: .lightGray))
        let senderBubble = ColoredItem(type: .senderBubble, set: ColorSet(primary: accentColor))
        let receiverBubble = ColoredItem(type: .receiverBubble, set: ColorSet(primary: UIColor(hex: 0x27252A)))
        let untranslatedBubble = ColoredItem(type: .untranslatedBubble, set: ColorSet(primary: UIColor(hex: 0x65C466)))
        let navigationBarBackground = ColoredItem(type: .navigationBarBackground, set: ColorSet(primary: backgroundColor))
        let navigationBarTitle = ColoredItem(type: .navigationBarTitle, set: ColorSet(primary: accentColor))
        let inputBarBackground = ColoredItem(type: .inputBarBackground, set: ColorSet(primary: backgroundColor))
        let listViewBackground = ColoredItem(type: .listViewBackground, set: ColorSet(primary: UIColor(hex: 0x1C1C1E)))
        
        let themedItems = [encapsulatingView,
                           accent,
                           titleText,
                           subtitleText,
                           senderBubble,
                           receiverBubble,
                           untranslatedBubble,
                           navigationBarBackground,
                           navigationBarTitle,
                           inputBarBackground,
                           listViewBackground]
        
        return UITheme(name: "Twilight", items: themedItems, style: .dark)
    }
    
    public static var bluesky: UITheme {
        let accentColor = UIColor(hex: 0x30AAF2)
        let backgroundColor = UIColor(hex: 0x1A1A1A)
        
        let encapsulatingView = ColoredItem(type: .encapsulatingView, set: ColorSet(primary: backgroundColor))
        let accent = ColoredItem(type: .primaryAccent, set: ColorSet(primary: accentColor))
        let titleText = ColoredItem(type: .titleText, set: ColorSet(primary: .white))
        let subtitleText = ColoredItem(type: .subtitleText, set: ColorSet(primary: .lightGray))
        let senderBubble = ColoredItem(type: .senderBubble, set: ColorSet(primary: accentColor))
        let receiverBubble = ColoredItem(type: .receiverBubble, set: ColorSet(primary: UIColor(hex: 0x27252A)))
        let untranslatedBubble = ColoredItem(type: .untranslatedBubble, set: ColorSet(primary: UIColor(hex: 0x65C466)))
        let navigationBarBackground = ColoredItem(type: .navigationBarBackground, set: ColorSet(primary: backgroundColor))
        let navigationBarTitle = ColoredItem(type: .navigationBarTitle, set: ColorSet(primary: accentColor))
        let inputBarBackground = ColoredItem(type: .inputBarBackground, set: ColorSet(primary: backgroundColor))
        let listViewBackground = ColoredItem(type: .listViewBackground, set: ColorSet(primary: UIColor(hex: 0x1C1C1E)))
        
        let themedItems = [encapsulatingView,
                           accent,
                           titleText,
                           subtitleText,
                           senderBubble,
                           receiverBubble,
                           untranslatedBubble,
                           navigationBarBackground,
                           navigationBarTitle,
                           inputBarBackground,
                           listViewBackground]
        
        return UITheme(name: "Bluesky", items: themedItems, style: .dark)
    }
    
    public static var firebrand: UITheme {
        let accentColor = UIColor(hex: 0xFF5252)
        let backgroundColor = UIColor(hex: 0x1A1A1A)
        
        let encapsulatingView = ColoredItem(type: .encapsulatingView, set: ColorSet(primary: backgroundColor))
        let accent = ColoredItem(type: .primaryAccent, set: ColorSet(primary: accentColor))
        let titleText = ColoredItem(type: .titleText, set: ColorSet(primary: .white))
        let subtitleText = ColoredItem(type: .subtitleText, set: ColorSet(primary: .lightGray))
        let senderBubble = ColoredItem(type: .senderBubble, set: ColorSet(primary: accentColor))
        let receiverBubble = ColoredItem(type: .receiverBubble, set: ColorSet(primary: UIColor(hex: 0x27252A)))
        let untranslatedBubble = ColoredItem(type: .untranslatedBubble, set: ColorSet(primary: UIColor(hex: 0x65C466)))
        let navigationBarBackground = ColoredItem(type: .navigationBarBackground, set: ColorSet(primary: backgroundColor))
        let navigationBarTitle = ColoredItem(type: .navigationBarTitle, set: ColorSet(primary: accentColor))
        let inputBarBackground = ColoredItem(type: .inputBarBackground, set: ColorSet(primary: backgroundColor))
        let listViewBackground = ColoredItem(type: .listViewBackground, set: ColorSet(primary: UIColor(hex: 0x1C1C1E)))
        
        let themedItems = [encapsulatingView,
                           accent,
                           titleText,
                           subtitleText,
                           senderBubble,
                           receiverBubble,
                           untranslatedBubble,
                           navigationBarBackground,
                           navigationBarTitle,
                           inputBarBackground,
                           listViewBackground]
        
        return UITheme(name: "Firebrand", items: themedItems, style: .dark)
    }
}

/**
 Use this enum to define new color types for specific theme items.
 */
public enum ColoredItemType {
    case encapsulatingView
    case primaryAccent
    
    case titleText
    case subtitleText
    
    case senderBubble
    case receiverBubble
    case untranslatedBubble
    
    case navigationBarBackground
    case navigationBarTitle
    
    case inputBarBackground
    case listViewBackground
}
