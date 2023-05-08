//
//  CustomColors.swift
//  Application
//
//  Created by Grant Brooks Goodman on DD/MM/20YY.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import SwiftUI
import UIKit

/**
 Use this extension to create custom `UIColors` based on the current theme.
 */
public extension UIColor {
    // MARK: Label Text
    static var subtitleTextColor: UIColor { ThemeService.currentTheme.color(for: .subtitleText) }
    static var titleTextColor: UIColor { ThemeService.currentTheme.color(for: .titleText) }
    
    // MARK: Message Bubbles
    static var receiverMessageBubbleColor: UIColor { ThemeService.currentTheme.color(for: .receiverBubble) }
    static var senderMessageBubbleColor: UIColor { ThemeService.currentTheme.color(for: .senderBubble) }
    static var untranslatedMessageBubbleColor: UIColor { ThemeService.currentTheme.color(for: .untranslatedBubble) }
    
    // MARK: Navigation Bar
    static var navigationBarBackgroundColor: UIColor { ThemeService.currentTheme.color(for: .navigationBarBackground) }
    static var navigationBarTitleColor: UIColor { ThemeService.currentTheme.color(for: .navigationBarTitle) }
    
    // MARK: Other
    static var encapsulatingViewBackgroundColor: UIColor { ThemeService.currentTheme.color(for: .encapsulatingView) }
    static var inputBarBackgroundColor: UIColor { ThemeService.currentTheme.color(for: .inputBarBackground) }
    static var listViewBackgroundColor: UIColor { ThemeService.currentTheme.color(for: .listViewBackground) }
    static var primaryAccentColor: UIColor { ThemeService.currentTheme.color(for: .primaryAccent) }
}

/**
 Provided to create convenience initializers for custom `Colors`.
 */
public extension Color {
    // MARK: Label Text
    static var subtitleTextColor: Color { ColorProvider.shared.subtitleTextColor }
    static var titleTextColor: Color { ColorProvider.shared.titleTextColor }
    
    // MARK: Navigation Bar
    static var navigationBarBackgroundColor: Color { ColorProvider.shared.navigationBarBackgroundColor }
    
    // MARK: Other
    static var encapsulatingViewBackgroundColor: Color { ColorProvider.shared.encapsulatingViewBackgroundColor }
    static var listViewBackgroundColor: Color { ColorProvider.shared.listViewBackgroundColor }
    static var primaryAccentColor: Color { ColorProvider.shared.primaryAccentColor }
}

/**
 This class can be used to access your custom `UIColors` in SwiftUI and keep them in sync.
 */
public class ColorProvider: ObservableObject {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Static Accessor
    public static let shared = ColorProvider()
    
    // Theme Information
    @Published public var currentThemeName = ThemeService.currentTheme.name
    @Published public var interfaceStyle = UITraitCollection.current.userInterfaceStyle
    
    // Label Text
    @Published public var subtitleTextColor = binding(with: .subtitleTextColor)
    @Published public var titleTextColor = binding(with: .titleTextColor)
    
    // Navigation Bar
    @Published public var navigationBarBackgroundColor = binding(with: .navigationBarBackgroundColor)
    
    // Other
    @Published public var encapsulatingViewBackgroundColor = binding(with: .encapsulatingViewBackgroundColor)
    @Published public var listViewBackgroundColor = binding(with: .listViewBackgroundColor)
    @Published public var primaryAccentColor = binding(with: .primaryAccentColor)
    
    //==================================================//
    
    /* MARK: - Synchronization Method */
    
    public func updateColorState() {
        subtitleTextColor = ColorProvider.binding(with: .subtitleTextColor)
        titleTextColor = ColorProvider.binding(with: .titleTextColor)
        
        navigationBarBackgroundColor = ColorProvider.binding(with: .navigationBarBackgroundColor)
        
        encapsulatingViewBackgroundColor = ColorProvider.binding(with: .encapsulatingViewBackgroundColor)
        listViewBackgroundColor = ColorProvider.binding(with: .listViewBackgroundColor)
        primaryAccentColor = ColorProvider.binding(with: .primaryAccentColor)
        
#if !EXTENSION
        UIApplication.shared.overrideUserInterfaceStyle(ThemeService.currentTheme.style)
#endif
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private static func binding(with color: UIColor) -> Color {
        return Binding(get: { Color(uiColor: color) }, set: { let _ = $0 }).wrappedValue
    }
}
