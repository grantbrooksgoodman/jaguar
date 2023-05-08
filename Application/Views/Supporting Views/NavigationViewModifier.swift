//
//  NavigationViewModifier.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 04/04/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import SwiftUI
import UIKit

struct NavigationBarModifier: ViewModifier {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    var backgroundColor: UIColor?
    var titleColor: UIColor?
    
    //==================================================//
    
    /* MARK: - Constructor */
    
    init(backgroundColor: Color, titleColor: UIColor?) {
        self.backgroundColor = UIColor(backgroundColor)
        
        let coloredAppearance = UINavigationBarAppearance()
        coloredAppearance.configureWithTransparentBackground()
        coloredAppearance.backgroundColor = .clear // The key is here. Change the actual bar to clear.
        coloredAppearance.titleTextAttributes = [.foregroundColor: titleColor ?? .white]
        coloredAppearance.largeTitleTextAttributes = [.foregroundColor: titleColor ?? .white]
        coloredAppearance.shadowColor = .clear
        
        UINavigationBar.appearance().standardAppearance = coloredAppearance
        UINavigationBar.appearance().compactAppearance = coloredAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance
        UINavigationBar.appearance().tintColor = titleColor
    }
    
    //==================================================//
    
    /* MARK: - View Body */
    
    func body(content: Content) -> some View {
        ZStack{
            content
            VStack {
                GeometryReader { geometry in
                    Color(self.backgroundColor ?? .clear)
                        .frame(height: geometry.safeAreaInsets.top)
                        .edgesIgnoringSafeArea(.top)
                    Spacer()
                }
            }
        }
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: - View Extensions */
public extension View {
    func navigationBarColor(backgroundColor: Color, titleColor: UIColor?) -> some View {
        Group {
            if ThemeService.currentTheme != AppThemes.default {
                self.modifier(NavigationBarModifier(backgroundColor: backgroundColor, titleColor: titleColor))
            } else {
                self
            }
        }
    }
}

